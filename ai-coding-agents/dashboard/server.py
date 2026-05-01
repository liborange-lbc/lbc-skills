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

# Phase 配置数组 - 集中定义，便于扩展
PHASE_CONFIG = [
    {
        "id": "P1", "name": "需求澄清", "agent": "interviewer",
        "log_file": "phase1-需求澄清.md",
        "output_files": ["需求清单.md"], "input_files": [],
        "design_principles": ["需求驱动全流程"],
        "parallel": False
    },
    {
        "id": "P2", "name": "知识采集", "agent": "planner",
        "log_file": "phase2-知识采集.md",
        "output_files": ["代码阅读报告.md", "知识摘要.md"],
        "input_files": ["需求清单.md"],
        "design_principles": ["GitNexus赋能"],
        "parallel": False
    },
    {
        "id": "P3", "name": "系分编写", "agent": "designer",
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
            {"role": "design-reviewer", "perspective": "架构合理性", "log_file": "phase4-评审-架构.md"},
            {"role": "performance-reviewer", "perspective": "性能容量", "log_file": "phase4-评审-性能.md"},
            {"role": "req-completeness-reviewer", "perspective": "需求完整度", "log_file": "phase4-评审-需求完整度.md"},
        ],
        "iteration_prefix": "phase4-迭代"
    },
    {
        "id": "P5", "name": "编码", "agent": "coder",
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
            {"role": "code-quality-reviewer", "perspective": "代码质量", "log_file": "phase6-CR-质量.md"},
            {"role": "code-security-reviewer", "perspective": "安全", "log_file": "phase6-CR-安全.md"},
            {"role": "code-req-reviewer", "perspective": "需求实现度", "log_file": "phase6-CR-需求实现度.md"},
        ],
        "iteration_prefix": "phase6-迭代"
    },
    {
        "id": "P7", "name": "测试", "agent": "tester",
        "log_file": "phase7-测试.md",
        "output_files": ["log/phase7-测试.md"],
        "input_files": ["代码", "需求清单.md"],
        "design_principles": ["GitNexus赋能"],
        "parallel": False
    },
    {
        "id": "P8", "name": "交付", "agent": "主Agent",
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
        phases = []

        for config in PHASE_CONFIG:
            if config["parallel"]:
                phases.append(self._scan_parallel_phase(config))
            else:
                phases.append(self._scan_single_phase(config))

        # 解析执行日志
        agent_registry, timeline = self._parse_execution_log()

        return {
            "requirement_name": requirement_name,
            "requirement_dir": str(self.base_dir.relative_to(self.project_root)),
            "last_scan_time": datetime.now().isoformat(timespec='seconds'),
            "phases": phases,
            "agent_registry": agent_registry,
            "timeline": timeline,
            "output_files": self._collect_output_files(phases),
        }

    def _scan_single_phase(self, config):
        """扫描单Agent Phase"""
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

        if config["log_file"]:
            log_path = self.log_dir / config["log_file"]
            content = self.cache.read(str(log_path))
            if content is not None:
                phase["status"] = self._determine_status(content, is_review=False)
                phase["summary"] = self._extract_summary(content)
            else:
                phase["status"] = "pending"
        else:
            # P8: 检查交付报告是否存在
            if config["id"] == "P8":
                delivery = self.base_dir / "交付报告.md"
                if delivery.exists():
                    content = self.cache.read(str(delivery))
                    phase["status"] = "pass" if content else "pending"
                    if content:
                        phase["summary"] = self._extract_summary(content)

        return phase

    def _scan_parallel_phase(self, config):
        """扫描并行评审 Phase"""
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

        all_pass = True
        any_running = False
        any_fail = False
        any_exists = False

        for reviewer in config["reviewers"]:
            log_path = self.log_dir / reviewer["log_file"]
            content = self.cache.read(str(log_path))

            agent_info = {
                "role": reviewer["role"],
                "perspective": reviewer["perspective"],
                "status": "pending",
                "log_file": f"log/{reviewer['log_file']}",
                "verdict": None,
                "stats": {"critical": 0, "high": 0, "medium": 0, "low": 0},
            }

            if content is not None:
                any_exists = True

                # 如果有复审文件，优先使用复审结果
                review_path = self.log_dir / reviewer["log_file"].replace('.md', '-复审.md')
                review_content = self.cache.read(str(review_path))
                effective_content = review_content if review_content else content

                status = self._determine_status(effective_content, is_review=True)
                agent_info["status"] = status

                if "## 判定：PASS" in effective_content:
                    agent_info["verdict"] = "PASS"
                elif "## 判定：FAIL" in effective_content:
                    agent_info["verdict"] = "FAIL"
                    any_fail = True
                    all_pass = False
                else:
                    all_pass = False
                    any_running = True

                # 解析问题统计
                agent_info["stats"] = self._parse_stats(content)
            else:
                all_pass = False

            phase["agents"].append(agent_info)

        # 扫描迭代文件
        iterations = self._scan_iterations(config.get("iteration_prefix", ""))
        phase["iterations"] = iterations
        phase["iteration_count"] = len(iterations)

        # 确定整体状态
        if not any_exists:
            phase["status"] = "pending"
        elif iterations and not all_pass:
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

    def _determine_status(self, content, is_review=False):
        """状态判断优先级"""
        if is_review:
            if "## 判定：PASS" in content:
                return "pass"
            if "## 判定：FAIL" in content:
                return "fail"
        # 检查完成标记（多种格式兼容）
        completion_markers = [
            "## 完成", "完成时间", "状态: 已完成", "状态：已完成",
            "## 结论", "## 结果", "Phase.*完成",
        ]
        for marker in completion_markers:
            if marker in content:
                return "pass"
        # 正则匹配 "- 状态: 已完成" 等变体
        if re.search(r'[状态|Status].*[已完成|完成|done|DONE]', content):
            return "pass"
        return "running"

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

    def _parse_execution_log(self):
        """解析执行日志，提取 Agent 注册表和时间线"""
        log_path = self.log_dir / "执行日志.md"
        content = self.cache.read(str(log_path))
        if content is None:
            return [], []

        agent_registry = []
        timeline = []
        in_registry = False

        for line in content.split('\n'):
            # Agent 注册表
            if '## Agent 注册表' in line or '## Agent注册表' in line:
                in_registry = True
                continue
            if in_registry:
                if line.startswith('##'):
                    in_registry = False
                elif line.startswith('|') and '---' not in line and '角色' not in line:
                    cols = [c.strip() for c in line.split('|')[1:-1]]
                    if len(cols) >= 4:
                        agent_registry.append({
                            "role": cols[0],
                            "agent_id": cols[1] if len(cols) > 1 else "",
                            "phase": cols[2] if len(cols) > 2 else "",
                            "status": cols[3] if len(cols) > 3 else "",
                            "note": cols[4] if len(cols) > 4 else "",
                        })

            # 时间线: 匹配 "- YYMMDD HHmm" 格式
            time_match = re.match(r'^-\s+(\d{6}\s+\d{4})\s+(.+)', line)
            if time_match:
                timeline.append({
                    "time": time_match.group(1),
                    "event": time_match.group(2),
                })

        return agent_registry, timeline

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
    args = parser.parse_args()

    # 确定项目根目录（server.py 所在的 dashboard/ 的父目录）
    dashboard_dir = Path(__file__).resolve().parent
    project_root = dashboard_dir.parent

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
