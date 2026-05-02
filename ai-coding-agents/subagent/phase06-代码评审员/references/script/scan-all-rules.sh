#!/usr/bin/env bash
#
# scan-all-rules.sh
# Step 4 可靠性检查的统一自动化预扫脚本
# CR 执行顺序：本脚本须先于 LLM 审查运行，输出再与清单/报告合并
#
# 覆盖: B(25/81) + M(6/27) + I(2/10) + A(8/29) + S(7/30) + G(4/45) = 52 / 222 条
#        其余需要类型信息 / AST / 数据流 / 语义分析，由 LLM 审查覆盖
#
# 等级统一: Blocker→P0, Major→P1, Info→P2; A/S/G 沿用各清单原始等级
#
# 用法: bash scan-all-rules.sh [目录或文件...]
#       默认扫描当前目录下所有 .java / .xml / .sql 文件
#
# 依赖: grep（必须）; ripgrep rg（可选，优先使用）
# 退出码: 0 = 无 P0, 1 = 存在 P0
#
# 注意: 正则扫描可能对注释/字符串字面量内容产生误报，需人工确认

set -u

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
Usage: scan-all-rules.sh [dir-or-file...]
  Scans Java/XML/SQL files for 52 rules (bug patterns + checklist).
  Default target: current directory.
  Exit: 0 = no P0, 1 = P0 found.
USAGE
    exit 0
fi

TARGETS=("${@:-.}")
FINDINGS=$(mktemp)
trap 'rm -f "$FINDINGS"' EXIT

# ── search backend (rg preferred, grep fallback) ──

USE_RG=false
command -v rg &>/dev/null && USE_RG=true

S='[[:space:]]'
W='[a-zA-Z0-9_]'
TAB=$(printf '\t')

do_grep() {
    local pat=$1; shift
    if $USE_RG; then
        rg -n --no-heading --type java -- "$pat" "$@" 2>/dev/null
    else
        grep -rn --include='*.java' -E -- "$pat" "$@" 2>/dev/null
    fi
    return 0
}

do_grep_xml() {
    local pat=$1; shift
    if $USE_RG; then
        rg -n --no-heading --type xml -- "$pat" "$@" 2>/dev/null
    else
        grep -rn --include='*.xml' -E -- "$pat" "$@" 2>/dev/null
    fi
    return 0
}

do_grep_sql() {
    local pat=$1; shift
    if $USE_RG; then
        rg -n --no-heading --type sql -- "$pat" "$@" 2>/dev/null
    else
        grep -rn --include='*.sql' -E -- "$pat" "$@" 2>/dev/null
    fi
    return 0
}

# ── helpers ──

report() { echo "[$1] $2 — $3: $4" >> "$FINDINGS"; }

emit() {
    local sev=$1 id=$2 name=$3
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        report "$sev" "$id" "$name" "$(echo "$m" | cut -d: -f1-2)"
    done
    return 0
}

scan() {
    local sev=$1 id=$2 name=$3 pat=$4
    do_grep "$pat" "${TARGETS[@]}" | emit "$sev" "$id" "$name"
}

scan_xml() {
    local sev=$1 id=$2 name=$3 pat=$4
    do_grep_xml "$pat" "${TARGETS[@]}" | emit "$sev" "$id" "$name"
}

scan_sql() {
    local sev=$1 id=$2 name=$3 pat=$4
    do_grep_sql "$pat" "${TARGETS[@]}" | emit "$sev" "$id" "$name"
}

scan_exclude() {
    local sev=$1 id=$2 name=$3 pat=$4 excl=$5
    do_grep "$pat" "${TARGETS[@]}" | { grep -Ev "$excl" 2>/dev/null || true; } | emit "$sev" "$id" "$name"
}

echo "=== Step 4 Rule Scan (B/M/I + A/S/G) ==="
echo "Targets: ${TARGETS[*]}"
echo "Engine:  $($USE_RG && echo 'ripgrep' || echo 'grep')"
echo ""

# ════════════════════════════════════════════════════════════════
#  Bug Patterns — bug-pattern-checklist.md
#  Blocker (25/81) → P0
# ════════════════════════════════════════════════════════════════

scan P0 B005 ArraysAsListPrimitiveArray \
    "Arrays\\.asList\\(${S}*new${S}+(int|long|double|float|short|byte|char|boolean)${S}*\\["

scan P0 B008 AvoidUsingExecutors \
    "Executors\\.(newCachedThreadPool|newFixedThreadPool|newSingleThreadExecutor|newScheduledThreadPool|newSingleThreadScheduledExecutor)${S}*\\("

scan P0 B010 BigDecimalLiteralDouble \
    "new${S}+BigDecimal\\(${S}*[0-9]+\\.[0-9]"

scan P0 B012 CalendarAddFixedDays \
    "\\.add\\(${S}*Calendar\\.DATE${S}*,${S}*365${S}*\\)"

scan P0 B013 CalendarSetHour \
    'Calendar\.HOUR([^_]|$)'

scan P0 B017 ComparingThisWithNull \
    "(this${S}*==${S}*null|null${S}*==${S}*this)"

scan P0 B022 DateFormatThreadSafety \
    "new${S}+SimpleDateFormat${S}*\\("

scan_exclude P0 B023 DeadException \
    "^${S}*new${S}+[A-Z]${W}*(Exception|Error)${S}*\\(" \
    'throw|return|='

scan P0 B026 EqualsNull \
    "\\.equals\\(${S}*null${S}*\\)"

scan P0 B028 ErroneousDateUtil \
    "DateUtil\\.formatDate${S}*\\("

scan P0 B036 IdentityHashMapBoxing \
    "IdentityHashMap${S}*<${S}*(Integer|Long|Short|Byte|Character|Boolean|Float|Double)"

scan P0 B049 MisusedDayOfYear \
    '"[^"]*MM[^"]*DD[^"]*"'

scan P0 B051 MisusedSystemPropertyGetter \
    "Boolean\\.getBoolean\\(${S}*\"(true|false)\""

scan P0 B052 MisusedWeekYear \
    '"[^"]*YYYY[^"]*[Mmd][^"]*"'

scan P0 B056 ModificationOnArraysAsList \
    "Arrays\\.asList\\(.*\\)\\.${S}*(add|remove|clear|set)${S}*\\("

scan P0 B059 NCopiesOfChar \
    "Collections\\.nCopies\\(${S}*'"

scan P0 B061 ObsoletedBase64Encoder \
    'sun\.misc\.(BASE64Encoder|BASE64Decoder)'

scan P0 B062 ObsoletedClassLoaderCast \
    "\\(URLClassLoader\\)${S}*ClassLoader\\.getSystemClassLoader"

scan P0 B063 ObsoletedJavaxXmlClass \
    'javax\.xml\.(bind|ws|soap)\.'

scan P0 B066 RandomCast \
    "\\(int\\)${S}*Math\\.random\\(\\)"

scan P0 B067 RandomModInteger \
    "\\.nextInt\\(\\)${S}*%"

scan P0 B071 SizeGreaterThanOrEqualsZero \
    "\\.size\\(\\)${S}*>=${S}*0"

scan P0 B073 StringBuilderInitWithChar \
    "new${S}+StringBuilder\\(${S}*'"

scan P0 B074 SubstringOfZero \
    "\\.substring\\(${S}*0${S}*\\)"

scan P0 B076 TransactionalNonPublicMethod \
    "@Transactional.*(private|protected)${S}"

# ════════════════════════════════════════════════════════════════
#  Bug Patterns — Major (6/27) → P1
# ════════════════════════════════════════════════════════════════

scan P1 M003 BoxedPrimitiveConstructor \
    "new${S}+(Integer|Long|Short|Byte|Float|Double|Boolean|Character)${S}*\\("

scan P1 M004 CatchAndPrintStackTrace \
    "\\.printStackTrace\\(${S}*\\)"

scan P1 M007 EmptyCatch \
    "catch${S}*\\([^)]*\\)${S}*\\{${S}*\\}"

scan P1 M016 JavaTimeDefaultTimeZone \
    "Local(Date|DateTime|Time)\\.now\\(${S}*\\)"

scan P1 M022 NullOptional \
    "Optional\\.of\\(${S}*null${S}*\\)"

scan_exclude P1 M027 ThreadLocalUsage \
    "ThreadLocal${S}*<" \
    'static'

# ════════════════════════════════════════════════════════════════
#  Bug Patterns — Info (2/10) → P2
# ════════════════════════════════════════════════════════════════

scan P2 I001 AssertExceptionDetailInfoPreferred \
    "@Test${S}*\\(${S}*expected${S}*="

scan P2 I004 JavaUtilDate \
    "new${S}+Date\\(${S}*\\)"

# ════════════════════════════════════════════════════════════════
#  Readability — readability-checklist.md  (8/29)
# ════════════════════════════════════════════════════════════════

scan P2 A1.3 TabCharacter "$TAB"

scan P2 A2.2 WildcardImport "^${S}*import${S}+.*\\*${S}*;"

scan_exclude P2 A3.4 LineWidthExceeded \
    '^.{121,}' \
    "^${S}*(import|package)${S}|https?://"

scan P2 A3.7 KeywordSpacing \
    "(if|for|while|switch|catch)\\(|\\}(else|catch|finally)"

scan P2 A4.1 PackageUppercase \
    "^${S}*package${S}+.*[A-Z]"

scan P1 A5.4 FinalizeOverride \
    "void${S}+finalize${S}*\\(${S}*\\)"

scan P2 A6.3 ModifierOrder \
    "(static|final)${S}+(public|private|protected)${S}|final${S}+static${S}"

scan P2 A6.5 LowercaseLongLiteral \
    '[0-9]l([^a-zA-Z0-9_]|$)'

# ════════════════════════════════════════════════════════════════
#  Security — security-checklist.md  (7/30)
# ════════════════════════════════════════════════════════════════

scan_xml P0 S1.1 MyBatisSqlInjection \
    '\$\{[^}]+\}'

scan P0 S4.1 CommandExecution \
    "Runtime\\.getRuntime\\(\\)\\.exec|new${S}+ProcessBuilder"

scan P0 S6.1 UnsafeDeserialization \
    "new${S}+ObjectInputStream"

scan P0 S9.1 HardcodedCredential \
    "(password|passwd|secret|apiKey|api_key|accessKey|access_key)${S}*=${S}*\"[^\"]{4,}\""

scan P1 S9.3 WeakCryptoAlgorithm \
    "MessageDigest\\.getInstance\\(${S}*\"(MD5|SHA-1|SHA1)\"|(Cipher|KeyGenerator)\\.getInstance\\(${S}*\"DES[/\"]"

scan_exclude P1 S9.4 InsecureRandom \
    "new${S}+Random\\(" \
    'SecureRandom|ThreadLocalRandom|test|Test|mock|Mock'

scan P1 S10.2 CorsWildcard \
    '(Allow-Origin|allowedOrigin|addAllowedOrigin).*"\*"'

# ════════════════════════════════════════════════════════════════
#  Reliability — reliability-checklist.md  (4/45)
# ════════════════════════════════════════════════════════════════

scan P2 G13.1 LogLevelMismatch \
    "\\.info\\(.*[Ee]xception|\\.debug\\(.*[Ee]xception|\\.error\\(.*[Ss]uccess"

scan P0 G14.1 DoubleForMoney \
    "double${S}+(amount|price|money|balance|fee|cost|payment|salary|wage|income|totalAmount|totalPrice|refund)"

scan_sql P0 G15.1 IncompatibleDDL \
    "DROP${S}+COLUMN|ALTER${S}+TABLE.*CHANGE${S}+[a-zA-Z]"

scan_exclude P0 G16.2 CatchWithoutLogging \
    "catch${S}*\\(" \
    'log\.|LOG\.|logger\.|throw |throws '

# ════════════════════════════════════════════════════════════════
#  Output
# ════════════════════════════════════════════════════════════════

echo ""
if [ -s "$FINDINGS" ]; then
    HAS_COLOR=false
    [ -t 1 ] && HAS_COLOR=true

    print_section() {
        local tag=$1
        grep "\\[$tag\\]" "$FINDINGS" 2>/dev/null | sort || true
    }

    colorize() {
        if $HAS_COLOR; then
            while IFS= read -r line; do
                case "$line" in
                    \[P0\]*) printf '\033[0;31m%s\033[0m\n' "$line" ;;
                    \[P1\]*) printf '\033[0;33m%s\033[0m\n' "$line" ;;
                    \[P2\]*) printf '\033[0;36m%s\033[0m\n' "$line" ;;
                    *)       echo "$line" ;;
                esac
            done
        else
            cat
        fi
    }

    { print_section P0; print_section P1; print_section P2; } | colorize

    echo ""
    P0=$(grep -c '\[P0\]' "$FINDINGS" 2>/dev/null) || P0=0
    P1=$(grep -c '\[P1\]' "$FINDINGS" 2>/dev/null) || P1=0
    P2=$(grep -c '\[P2\]' "$FINDINGS" 2>/dev/null) || P2=0
    T=$((P0 + P1 + P2))
    echo "=== Summary: ${T} findings (P0=${P0}, P1=${P1}, P2=${P2}) | 52/222 rules scanned ==="

    [ "$P0" -gt 0 ] && exit 1 || exit 0
else
    echo "=== No findings. 52/222 rules scanned ==="
    exit 0
fi
