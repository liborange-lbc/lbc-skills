#!/usr/bin/env python3
"""流水线可视化 Dashboard 后端服务器 - 零依赖，仅用 Python 标准库"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Agent 执行记录事件类型 → Dashboard 状态映射
# 与 SKILL.md 和 reference/执行日志规范.md 保持一致，不可自创事件名
AGENT_EVENTS = {
    "启动":     "running",
    "完成":     "pass",
    "PASS":    "pass",
    "FAIL":    "fail",
    "Resume":  "running",
    "降级新建": "running",
}

# Phase 配置数组 - 集中定义，便于扩展
# display_name 为 Agent 执行记录中 Agent名称 列的唯一合法值
PHASE_CONFIG = [
    {
        "id": "P1", "name": "需求澄清", "agent": "interviewer",
        "display_name": "P1-需求访谈员",
        "log_file": "phase1-需求澄清.md",
        "output_files": ["需求清单.md"], "input_files": [],
        "design_principles": ["需求驱动全流程"],
        "parallel": False
    },
    {
        "id": "P2", "name": "知识采集", "agent": "collector",
        "display_name": "P2-知识采集员",
        "log_file": "phase2-知识采集.md",
        "output_files": ["代码阅读报告.md", "知识摘要.md"],
        "input_files": ["需求清单.md"],
        "design_principles": ["GitNexus赋能"],
        "parallel": False
    },
    {
        "id": "P3", "name": "系分编写", "agent": "designer",
        "display_name": "P3-系分设计师",
        "log_file": "phase3-系分编写.md",
        "output_files": ["系分文档.md", "需求追踪矩阵.md"],
        "input_files": ["需求清单.md", "代码阅读报告.md", "知识摘要.md"],
        "design_principles": ["文档驱动交接"],
        "parallel": False
    },
    {
        "id": "P4", "name": "系分评审", "agent": None,
        "log_file": None,
        "output_files": [],
        "input_files": ["系分文档.md", "需求追踪矩阵.md"],
        "design_principles": ["Resume优于新建", "经验库累积"],
        "parallel": True,
        "reviewers": [
            {"role": "design-reviewer", "perspective": "架构合理性", "log_file": "phase4-评审-架构.md", "display_name": "P4-架构评审员"},
            {"role": "performance-reviewer", "perspective": "性能容量", "log_file": "phase4-评审-性能.md", "display_name": "P4-性能评审员"},
            {"role": "req-completeness-reviewer", "perspective": "需求完整度", "log_file": "phase4-评审-需求完整度.md", "display_name": "P4-需求完整度评审员"},
        ],
        "iteration_prefix": "phase4-迭代"
    },
    {
        "id": "P5", "name": "编码", "agent": "coder",
        "display_name": "P5-编码工程师",
        "log_file": "phase5-编码.md",
        "output_files": [],
        "input_files": ["系分文档.md", "需求追踪矩阵.md"],
        "design_principles": ["扩展优于硬编码"],
        "parallel": False
    },
    {
        "id": "P6", "name": "代码评审", "agent": None,
        "log_file": None,
        "output_files": [],
        "input_files": ["代码"],
        "design_principles": ["Resume优于新建", "经验库累积"],
        "parallel": True,
        "reviewers": [
            {"role": "code-quality-reviewer", "perspective": "代码质量", "log_file": "phase6-CR-质量.md", "display_name": "P6-代码质量评审员"},
            {"role": "code-security-reviewer", "perspective": "安全", "log_file": "phase6-CR-安全.md", "display_name": "P6-安全评审员"},
            {"role": "code-req-reviewer", "perspective": "需求实现度", "log_file": "phase6-CR-需求实现度.md", "display_name": "P6-需求实现度评审员"},
        ],
        "iteration_prefix": "phase6-迭代"
    },
    {
        "id": "P7", "name": "测试", "agent": "tester",
        "display_name": "P7-测试工程师",
        "log_file": "phase7-测试.md",
        "output_files": ["log/phase7-测试.md"],
        "input_files": ["代码", "需求清单.md"],
        "design_principles": ["GitNexus赋能"],
        "parallel": False
    },
    {
        "id": "P8", "name": "交付", "agent": "主Agent",
        "display_name": "P8-主Agent",
        "log_file": None,
        "output_files": ["交付报告.md", "执行摘要.md"],
        "input_files": ["所有日志"],
        "design_principles": ["主Agent纯调度"],
        "parallel": False
    },
]


class FileCache:
    """基于 mtime 的文件读取缓存"""

    def __init__(self):
        self._cache = {}  # path -> (mtime, content)

    def read(self, path):
        """读取文件，如未修改则返回缓存"""
        try:
            mtime = os.path.getmtime(path)
            if path in self._cache and self._cache[path][0] == mtime:
                return self._cache[path][1]
            with open(path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            self._cache[path] = (mtime, content)
            return content
        except (OSError, IOError):
            return None


class LogScanner:
    """扫描 log 目录，构建 phases 状态数据"""

    def __init__(self, base_dir, project_root):
        self.base_dir = Path(base_dir)
        self.log_dir = self.base_dir / "log"
        self.project_root = Path(project_root)
        self.cache = FileCache()

    def scan(self):
        """执行完整扫描，返回状态 JSON 结构"""
        requirement_name = self.base_dir.name

        # Step 1: 解析执行记录，构建 phase_map（状态唯一来源）
        agent_records = self._parse_execution_records()
        phase_map = self._build_phase_map(agent_records)

        # Step 2: 扫描各 Phase（状态从 phase_map，详情从 log 文件）
        phases = []
        for config in PHASE_CONFIG:
            if config["parallel"]:
                phases.append(self._scan_parallel_phase(config, agent_records, phase_map))
            else:
                phases.append(self._scan_single_phase(config, phase_map))

        return {
            "requirement_name": requirement_name,
            "requirement_dir": str(self.base_dir.relative_to(self.project_root)),
            "last_scan_time": datetime.now().isoformat(timespec='seconds'),
            "phases": phases,
            "agent_records": agent_records,
            "output_files": self._collect_output_files(phases),
        }

    def _scan_single_phase(self, config, phase_map):
        """扫描单Agent Phase — 状态从执行记录，详情从 log 文件"""
        phase = {
            "id": config["id"],
            "name": config["name"],
            "agent": config["agent"],
            "status": "pending",
            "log_file": f"log/{config['log_file']}" if config["log_file"] else None,
            "output_files": config["output_files"],
            "input_files": config["input_files"],
            "design_principles": config["design_principles"],
            "summary": "",
            "parallel": False,
        }

        phase_id = config["id"]

        # 状态来源 1: 执行记录（优先）
        if phase_id in phase_map:
            agents = phase_map[phase_id]
            statuses = [a["status"] for a in agents.values()]
            if all(s == "pass" for s in statuses):
                phase["status"] = "pass"
            elif any(s == "fail" for s in statuses):
                phase["status"] = "fail"
            elif any(s == "running" for s in statuses):
                phase["status"] = "running"

            # 时间: 取该 phase 下所有 agent 的时间范围
            all_durations = [a["duration_seconds"] for a in agents.values()
                            if a["duration_seconds"] is not None]
            all_starts = [a["start_time"] for a in agents.values() if a["start_time"]]
            all_ends = [a["end_time"] for a in agents.values() if a["end_time"]]
            if all_durations:
                phase["duration_seconds"] = max(all_durations)
            if all_starts:
                phase["start_time"] = min(all_starts)
            if all_ends:
                phase["end_time"] = max(all_ends)
            # spans: 单 agent phase 直接取该 agent 的 spans
            agent_list = list(agents.values())
            if len(agent_list) == 1:
                phase["spans"] = agent_list[0].get("spans", [])

        # 详情: 从 log 文件读取摘要
        if config["log_file"]:
            log_path = self.log_dir / config["log_file"]
            content = self.cache.read(str(log_path))
            if content is not None:
                phase["summary"] = self._extract_summary(content)

        # P8 特殊: 检查交付报告
        if config["id"] == "P8" and phase["status"] == "pending":
            delivery = self.base_dir / "交付报告.md"
            if delivery.exists():
                content = self.cache.read(str(delivery))
                phase["status"] = "pass" if content else "pending"
                if content:
                    phase["summary"] = self._extract_summary(content)

        return phase

    def _scan_parallel_phase(self, config, records, phase_map):
        """扫描并行评审 Phase — 状态从执行记录，统计从 log 文件"""
        phase = {
            "id": config["id"],
            "name": config["name"],
            "status": "pending",
            "parallel": True,
            "iteration_count": 0,
            "max_iteration": 3,
            "agents": [],
            "iterations": [],
            "input_files": config["input_files"],
            "output_files": config["output_files"],
            "design_principles": config["design_principles"],
        }

        phase_id = config["id"]
        phase_agents = phase_map.get(phase_id, {})

        all_pass = True
        any_running = False
        any_fail = False
        any_exists = bool(phase_agents)

        for reviewer in config["reviewers"]:
            agent_info = {
                "role": reviewer["role"],
                "perspective": reviewer["perspective"],
                "status": "pending",
                "log_file": f"log/{reviewer['log_file']}",
                "verdict": None,
                "stats": {"critical": 0, "high": 0, "medium": 0, "low": 0},
            }

            # 状态来源 1: 执行记录（通过 display_name 精确匹配）
            display_name = reviewer.get("display_name", "")
            agent_data = phase_agents.get(display_name)

            if agent_data:
                agent_info["status"] = agent_data["status"]
                agent_info["duration_seconds"] = agent_data.get("duration_seconds")
                agent_info["spans"] = agent_data.get("spans", [])
                if agent_data["event"] == "PASS":
                    agent_info["verdict"] = "PASS"
                elif agent_data["event"] == "FAIL":
                    agent_info["verdict"] = "FAIL"
                    any_fail = True
                    all_pass = False
                elif agent_data["status"] == "running":
                    any_running = True
                    all_pass = False
                else:
                    all_pass = False
            else:
                all_pass = False

            # 统计: 从 log 文件读取（评审详细数据）
            log_path = self.log_dir / reviewer["log_file"]
            content = self.cache.read(str(log_path))
            if content is not None:
                agent_info["stats"] = self._parse_stats(content)

            phase["agents"].append(agent_info)

        # Phase 整体耗时: 从所有 agent 的最早 start 到最晚 end
        all_agent_durations = [a.get("duration_seconds") for a in phase["agents"]
                               if a.get("duration_seconds") is not None]
        if all_agent_durations:
            phase["duration_seconds"] = max(all_agent_durations)

        # 迭代次数: 优先从迭代文件，其次从执行记录中 Resume 事件计数
        iterations = self._scan_iterations(config.get("iteration_prefix", ""))
        phase["iterations"] = iterations
        phase["iteration_count"] = len(iterations)
        if not iterations and records:
            resume_count = sum(1 for r in records
                               if r["phase"] == phase_id and r["event"] == "Resume")
            reviewer_count = len(config["reviewers"]) or 1
            if resume_count > 0:
                phase["iteration_count"] = max(1, resume_count // reviewer_count)

        # 确定整体状态
        if not any_exists:
            phase["status"] = "pending"
        elif phase["iteration_count"] > 0 and not all_pass:
            phase["status"] = "iterating"
        elif all_pass:
            phase["status"] = "pass"
        elif any_fail:
            phase["status"] = "fail"
        elif any_running:
            phase["status"] = "running"
        else:
            phase["status"] = "pending"

        return phase

    def _extract_summary(self, content):
        """从文件首段提取摘要（<=100字）"""
        lines = content.split('\n')
        summary_lines = []
        started = False
        for line in lines:
            stripped = line.strip()
            # 跳过标题行
            if stripped.startswith('#'):
                if started:
                    break
                started = True
                continue
            if started and stripped:
                summary_lines.append(stripped)
                if len(''.join(summary_lines)) > 100:
                    break
            elif started and not stripped and summary_lines:
                break
        result = ' '.join(summary_lines)
        return result[:100] if len(result) > 100 else result

    def _parse_stats(self, content):
        """从评审内容解析问题统计"""
        stats = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for level in stats:
            # 匹配 "CRITICAL: 1" 或 "critical: 1" 格式
            match = re.search(rf'{level}\s*[:：]\s*(\d+)', content, re.IGNORECASE)
            if match:
                stats[level] = int(match.group(1))
        return stats

    def _scan_iterations(self, prefix):
        """扫描迭代文件"""
        if not prefix or not self.log_dir.exists():
            return []
        iterations = []
        for i in range(1, 4):  # 最多3轮
            filename = f"{prefix}-{i}.md"
            path = self.log_dir / filename
            content = self.cache.read(str(path))
            if content is not None:
                result = "PASS" if "PASS" in content else "FAIL" if "FAIL" in content else "running"
                iterations.append({
                    "round": i,
                    "log_file": f"log/{filename}",
                    "result": result,
                })
            else:
                break
        return iterations

    def _parse_execution_records(self):
        """解析 Agent 执行记录表"""
        log_path = self.log_dir / "执行日志.md"
        content = self.cache.read(str(log_path))
        if content is None:
            return []

        records = []
        in_section = False

        for line in content.split('\n'):
            if '## Agent 执行记录' in line:
                in_section = True
                continue
            if in_section and line.startswith('##'):
                in_section = False
                continue

            if not in_section or not line.startswith('|') or '---' in line:
                continue

            cols = [c.strip() for c in line.split('|')[1:-1]]
            # 跳过表头: | # | 时间 | Phase | ...
            if not cols or cols[0] == '#' or cols[0] == '序号':
                continue
            if len(cols) >= 6:
                try:
                    seq = int(cols[0])
                except ValueError:
                    continue
                records.append({
                    "seq": seq,
                    "time": cols[1],
                    "phase": cols[2],
                    "agent_name": cols[3],
                    "agent_id": cols[4],
                    "event": cols[5],
                    "note": cols[6] if len(cols) > 6 else "",
                })

        return records

    def _build_phase_map(self, records):
        """从执行记录构建 {phase_id: {agent_name: 最新状态+时间+spans}} 映射"""
        phase_map = {}
        open_spans = {}  # (phase, agent_name) -> span_start_time

        for r in records:
            phase = r["phase"]
            agent = r["agent_name"]
            key = (phase, agent)
            status = AGENT_EVENTS.get(r["event"], "running")

            if phase not in phase_map:
                phase_map[phase] = {}
            if agent not in phase_map[phase]:
                phase_map[phase][agent] = {
                    "agent_id": r["agent_id"],
                    "status": status,
                    "event": r["event"],
                    "note": r["note"],
                    "start_time": None,
                    "end_time": None,
                    "duration_seconds": None,
                    "spans": [],
                }

            entry = phase_map[phase][agent]
            entry["status"] = status
            entry["event"] = r["event"]
            entry["note"] = r["note"]
            entry["agent_id"] = r["agent_id"]

            if r["event"] in ("启动", "Resume", "降级新建"):
                if entry["start_time"] is None:
                    entry["start_time"] = r["time"]
                open_spans[key] = r["time"]

            if r["event"] in ("完成", "PASS", "FAIL"):
                entry["end_time"] = r["time"]
                span_start = open_spans.pop(key, None)
                if span_start:
                    dur = self._calc_duration(span_start, r["time"])
                    label = "初次" if not entry["spans"] else f"第{len(entry['spans'])}次修正"
                    entry["spans"].append({
                        "label": label,
                        "start": span_start,
                        "end": r["time"],
                        "duration_seconds": dur,
                    })

        # 处理仍在 running 的 agent：追加临时 span + 计算总 duration
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        for phase_id, agents in phase_map.items():
            for agent_name, info in agents.items():
                key = (phase_id, agent_name)
                if key in open_spans and info["status"] == "running":
                    dur = self._calc_duration(open_spans[key], now_str)
                    info["spans"].append({
                        "label": "进行中" if not info["spans"] else f"第{len(info['spans'])}次修正(进行中)",
                        "start": open_spans[key],
                        "end": None,
                        "duration_seconds": dur,
                    })
                info["duration_seconds"] = self._calc_duration(
                    info["start_time"], info["end_time"],
                    is_running=(info["status"] == "running"),
                )
        return phase_map

    @staticmethod
    def _calc_duration(start_str, end_str, is_running=False):
        """计算持续时间（秒），running 状态计到当前时刻"""
        if not start_str:
            return None
        try:
            start = datetime.strptime(start_str, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            return None
        if end_str:
            try:
                end = datetime.strptime(end_str, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                return None
        elif is_running:
            end = datetime.now()
        else:
            return None
        return max(0, int((end - start).total_seconds()))

    def _collect_output_files(self, phases):
        """收集所有 Phase 的产出文件"""
        output_files = []
        for phase in phases:
            for f in phase.get("output_files", []):
                rel_dir = str(self.base_dir.relative_to(self.project_root))
                output_files.append({
                    "name": f,
                    "path": f"{rel_dir}/{f}",
                    "phase": phase["id"],
                })
        return output_files


class DashboardHandler(SimpleHTTPRequestHandler):
    """自定义 HTTP Handler，处理 API 和静态文件"""

    scanner = None
    project_root = None
    dashboard_dir = None

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/status':
            self._handle_status(parsed)
        elif path == '/api/dirs':
            self._handle_dirs()
        elif path == '/api/file':
            self._handle_file(parsed)
        else:
            self._handle_static(path)

    def _handle_status(self, parsed):
        """处理 /api/status 请求"""
        params = parse_qs(parsed.query)
        req_dir = params.get('dir', [None])[0]

        try:
            if req_dir:
                base_dir = Path(self.project_root) / req_dir
            else:
                base_dir = self._find_default_requirement_dir()

            if not base_dir or not base_dir.exists():
                self._send_json({"error": "requirement directory not found"}, 404)
                return

            scanner = LogScanner(str(base_dir), self.project_root)
            data = scanner.scan()
            self._send_json(data)
        except Exception as e:
            self._send_json({"error": str(e)}, 500)

    def _handle_file(self, parsed):
        """处理 /api/file 请求 - 安全约束"""
        params = parse_qs(parsed.query)
        file_path = params.get('path', [None])[0]

        if not file_path:
            self._send_json({"error": "path parameter required"}, 400)
            return

        # 安全检查: 必须以 .ai-coding/ 开头，禁止 ..
        if not file_path.startswith('.ai-coding/') or '..' in file_path:
            self._send_json({"error": "access denied"}, 403)
            return

        full_path = Path(self.project_root) / file_path
        if not full_path.exists():
            self._send_json({"error": "file not found"}, 404)
            return

        try:
            with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            fmt = "markdown" if file_path.endswith('.md') else "text"
            self._send_json({"path": file_path, "content": content, "format": fmt})
        except Exception as e:
            self._send_json({"error": str(e)}, 500)

    def _handle_static(self, path):
        """返回 dashboard/ 下的静态文件"""
        if path == '/' or path == '':
            path = '/index.html'

        # 安全检查
        if '..' in path:
            self.send_error(403)
            return

        file_path = Path(self.dashboard_dir) / path.lstrip('/')
        if not file_path.exists() or not file_path.is_file():
            self.send_error(404)
            return

        # MIME 类型映射
        mime_map = {
            '.html': 'text/html; charset=utf-8',
            '.css': 'text/css; charset=utf-8',
            '.js': 'application/javascript; charset=utf-8',
            '.json': 'application/json; charset=utf-8',
        }
        ext = file_path.suffix
        content_type = mime_map.get(ext, 'application/octet-stream')

        with open(file_path, 'rb') as f:
            content = f.read()

        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', len(content))
        self.end_headers()
        self.wfile.write(content)

    def _handle_dirs(self):
        """列出 .ai-coding/ 下所有需求目录"""
        ai_coding_dir = Path(self.project_root) / '.ai-coding'
        dirs = []
        if ai_coding_dir.exists():
            for entry in sorted(ai_coding_dir.iterdir()):
                if entry.is_dir() and not entry.name.startswith('.'):
                    # 检查是否有 log 目录判断是否为有效需求目录
                    has_log = (entry / 'log').exists()
                    # 简单判断运行状态
                    status = "idle"
                    if has_log:
                        log_dir = entry / 'log'
                        log_files = list(log_dir.glob('*.md'))
                        if any('phase7' in f.name for f in log_files):
                            status = "completed"
                        elif any('phase' in f.name for f in log_files):
                            status = "running"
                    dirs.append({
                        "name": entry.name,
                        "path": f".ai-coding/{entry.name}",
                        "has_log": has_log,
                        "status": status
                    })
        self._send_json({"dirs": dirs})

    def _find_default_requirement_dir(self):
        """自动检测 .ai-coding/ 下第一个需求子目录"""
        ai_coding_dir = Path(self.project_root) / '.ai-coding'
        if not ai_coding_dir.exists():
            return None
        for entry in sorted(ai_coding_dir.iterdir()):
            if entry.is_dir() and not entry.name.startswith('.'):
                return entry
        return None

    def _send_json(self, data, status=200):
        """发送 JSON 响应"""
        body = json.dumps(data, ensure_ascii=False, indent=2).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        """简化日志输出"""
        sys.stderr.write(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}\n")


def main():
    parser = argparse.ArgumentParser(description='流水线可视化 Dashboard 服务器')
    parser.add_argument('--port', type=int, default=8080, help='监听端口 (默认 8080)')
    parser.add_argument('--dir', type=str, default=None, help='指定需求目录 (如 .ai-coding/流水线可视化Dashboard)')
    parser.add_argument('--project-root', type=str, default=None, help='项目根目录 (默认为当前工作目录)')
    args = parser.parse_args()

    dashboard_dir = Path(__file__).resolve().parent
    project_root = Path(args.project_root).resolve() if args.project_root else Path.cwd()

    DashboardHandler.project_root = str(project_root)
    DashboardHandler.dashboard_dir = str(dashboard_dir)

    try:
        server = ThreadingHTTPServer(('0.0.0.0', args.port), DashboardHandler)
        print(f"Dashboard 启动: http://localhost:{args.port}")
        print(f"项目根目录: {project_root}")
        print(f"按 Ctrl+C 停止")
        server.serve_forever()
    except OSError as e:
        if 'Address already in use' in str(e):
            print(f"错误: 端口 {args.port} 已被占用，请使用 --port 指定其他端口")
        else:
            print(f"错误: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n服务已停止")
        server.shutdown()


if __name__ == '__main__':
    main()
