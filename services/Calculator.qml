pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Engineering calculator service for launcher supporting:
// - basic arithmetic (+, -, *, /, %, ^, **)
// - factorials (5!), roots (sqrt, cbrt, √), powers
// - trigonometry (sin, cos, tan/tg, cot/ctg, asin, acos, atan/atg, sinh, cosh, tanh) with degree support (30°, 45 deg)
// - logarithms (ln, lg, log10, log2, log(x), log(base, x)) and exponent (exp)
// - constants (pi, π, e, tau, phi, ans)
// - calculation history persistence and clipboard copying (wl-copy)
Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + (Quickshell.env("USER") || "user"))
    readonly property string stateDir: homeDir + "/.local/state/dynamic-notch"
    readonly property string historyPath: stateDir + "/calc-history.json"

    // Calculation history: array of { expr: string, result: string, time: number }
    property var history: []
    property string lastCopied: ""

    readonly property real lastAnswer: {
        if (history.length > 0) {
            const v = Number(history[0].result);
            if (!isNaN(v)) return v;
        }
        return 0;
    }

    Timer {
        id: copiedResetTimer
        interval: 1600
        onTriggered: root.lastCopied = ""
    }

    Component.onCompleted: {
        initProc.running = true;
    }

    Process {
        id: initProc
        command: ["sh", "-c", "mkdir -p \"$1\" && [ -f \"$2\" ] || printf '[]' > \"$2\"", "sh", root.stateDir, root.historyPath]
        onExited: {
            if (historyFile.path === root.historyPath) {
                historyFile.reload();
            } else {
                historyFile.path = root.historyPath;
            }
        }
    }

    FileView {
        id: historyFile
        path: ""
        onLoaded: {
            try {
                const txt = historyFile.text();
                if (!txt || !txt.trim()) return;
                const parsed = JSON.parse(txt);
                if (Array.isArray(parsed)) {
                    root.history = parsed.slice(0, 60);
                }
            } catch (e) {}
        }
    }

    function saveHistoryDisk() {
        const json = JSON.stringify(root.history);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", stateDir, json, historyPath]);
    }

    function copyText(val) {
        const str = String(val);
        Quickshell.execDetached(["wl-copy", "--", str]);
        root.lastCopied = str;
        copiedResetTimer.restart();
    }

    function recordAndCopy(expr, result) {
        const cleanExpr = String(expr || "").trim().replace(/^=\s*/, "");
        const cleanRes = String(result ?? "").trim();
        if (!cleanRes) return;

        copyText(cleanRes);

        if (cleanExpr) {
            let next = root.history.slice();
            // Remove duplicate with the same expression to bring it to top
            next = next.filter(item => item.expr !== cleanExpr);
            next.unshift({
                expr: cleanExpr,
                result: cleanRes,
                time: Date.now()
            });
            if (next.length > 50) next = next.slice(0, 50);
            root.history = next;
            saveHistoryDisk();
        }
    }

    function removeHistoryAt(index) {
        if (index < 0 || index >= root.history.length) return;
        const next = root.history.slice();
        next.splice(index, 1);
        root.history = next;
        saveHistoryDisk();
    }

    function clearHistory() {
        root.history = [];
        saveHistoryDisk();
    }

    // Mathematical functions and helpers
    function _fact(n) {
        if (n < 0 || ! isFinite(n)) return NaN;
        if (Math.abs(n - Math.round(n)) > 1e-9) return NaN;
        const k = Math.round(n);
        if (k > 170) return Infinity;
        let r = 1;
        for (let i = 2; i <= k; i++) r *= i;
        return r;
    }

    function _gcd(a, b) {
        a = Math.abs(Math.round(a));
        b = Math.abs(Math.round(b));
        while (b !== 0) {
            const t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    function _lcm(a, b) {
        if (a === 0 || b === 0) return 0;
        return Math.abs(Math.round(a) * Math.round(b)) / _gcd(a, b);
    }

    function _ncr(n, r) {
        n = Math.round(n);
        r = Math.round(r);
        if (r < 0 || r > n) return 0;
        if (r === 0 || r === n) return 1;
        r = Math.min(r, n - r);
        let res = 1;
        for (let i = 1; i <= r; i++) {
            res = res * (n - r + i) / i;
        }
        return Math.round(res);
    }

    readonly property var _knownFuncs: ({
        "sin": true, "cos": true, "tan": true, "tg": true, "cot": true, "ctg": true,
        "sec": true, "csc": true,
        "asin": true, "acos": true, "atan": true, "atg": true, "atan2": true,
        "sinh": true, "cosh": true, "tanh": true,
        "sqrt": true, "cbrt": true, "root": true,
        "ln": true, "lg": true, "log": true, "log10": true, "log2": true, "exp": true,
        "abs": true, "floor": true, "ceil": true, "round": true, "trunc": true, "sign": true,
        "deg": true, "rad": true, "fact": true,
        "min": true, "max": true, "gcd": true, "lcm": true, "ncr": true, "comb": true
    })

    readonly property var _knownConsts: ({
        "pi": Math.PI,
        "π": Math.PI,
        "e": Math.E,
        "tau": Math.PI * 2,
        "τ": Math.PI * 2,
        "phi": (1 + Math.sqrt(5)) / 2
    })

    // Mathematical expression tokenization
    function _tokenize(input) {
        const tokens = [];
        let i = 0;
        const s = input;
        const len = s.length;

        while (i < len) {
            const ch = s[i];

            if (/\s/.test(ch)) {
                i++;
                continue;
            }

            // Square root symbol √
            if (ch === "√") {
                tokens.push({ type: "func", value: "sqrt" });
                i++;
                continue;
            }

            // Degree symbol °
            if (ch === "°") {
                tokens.push({ type: "op", value: "°" });
                i++;
                continue;
            }

            // Numbers (including 0xFF, 0b1010, decimals with . or , and exponential notation 1e-5)
            if (/[0-9]/.test(ch) || ((ch === "." || ch === ",") && i + 1 < len && /[0-9]/.test(s[i + 1]))) {
                let numStr = "";
                if (ch === "0" && i + 1 < len && (s[i + 1] === "x" || s[i + 1] === "X")) {
                    numStr = "0x";
                    i += 2;
                    while (i < len && /[0-9a-fA-F]/.test(s[i])) {
                        numStr += s[i++];
                    }
                    if (numStr === "0x") return null;
                    tokens.push({ type: "num", value: parseInt(numStr, 16) });
                    continue;
                }
                if (ch === "0" && i + 1 < len && (s[i + 1] === "b" || s[i + 1] === "B")) {
                    i += 2;
                    while (i < len && /[01]/.test(s[i])) {
                        numStr += s[i++];
                    }
                    if (numStr === "") return null;
                    tokens.push({ type: "num", value: parseInt(numStr, 2) });
                    continue;
                }

                let hasDot = false;
                while (i < len) {
                    const c = s[i];
                    if (/[0-9]/.test(c)) {
                        numStr += c;
                        i++;
                    } else if (!hasDot && (c === "." || (c === "," && i + 1 < len && /[0-9]/.test(s[i + 1])))) {
                        hasDot = true;
                        numStr += ".";
                        i++;
                    } else {
                        break;
                    }
                }
                // Exponential notation (e.g., 1.5e-3)
                if (i < len && (s[i] === "e" || s[i] === "E")) {
                    const nextCh = i + 1 < len ? s[i + 1] : "";
                    const nextNextCh = i + 2 < len ? s[i + 2] : "";
                    if (/[0-9]/.test(nextCh) || ((nextCh === "+" || nextCh === "-") && /[0-9]/.test(nextNextCh))) {
                        numStr += s[i++];
                        if (s[i] === "+" || s[i] === "-") numStr += s[i++];
                        while (i < len && /[0-9]/.test(s[i])) numStr += s[i++];
                    }
                }
                const val = Number(numStr);
                if (isNaN(val)) return null;
                tokens.push({ type: "num", value: val });
                continue;
            }

            // Identifiers (functions, constants, mod, deg)
            if (/[a-zA-Zπτ]/.test(ch)) {
                let id = "";
                while (i < len && /[a-zA-Z0-9_πτ]/.test(s[i])) {
                    id += s[i++];
                }
                const lower = id.toLowerCase();
                if (lower === "mod") {
                    tokens.push({ type: "op", value: "%" });
                } else if (lower === "deg" && (i >= len || s[i] !== "(")) {
                    // Postfix `45 deg` -> convert degrees to radians
                    tokens.push({ type: "op", value: "°" });
                } else if (lower === "ans") {
                    tokens.push({ type: "num", value: root.lastAnswer, isConst: true });
                } else if (root._knownConsts[lower] !== undefined) {
                    tokens.push({ type: "num", value: root._knownConsts[lower], isConst: true });
                } else if (root._knownFuncs[lower] === true) {
                    tokens.push({ type: "func", value: lower });
                } else {
                    // Unknown word — not a mathematical expression, likely app search
                    return null;
                }
                continue;
            }

            // Two-character exponentiation operator **
            if (ch === "*" && i + 1 < len && s[i + 1] === "*") {
                tokens.push({ type: "op", value: "^" });
                i += 2;
                continue;
            }

            if (ch === "+" || ch === "-" || ch === "*" || ch === "/" || ch === "^" || ch === "%" || ch === "!") {
                tokens.push({ type: "op", value: ch });
                i++;
                continue;
            }
            if (ch === "×") {
                tokens.push({ type: "op", value: "*" });
                i++;
                continue;
            }
            if (ch === "÷" || ch === ":") {
                tokens.push({ type: "op", value: "/" });
                i++;
                continue;
            }
            if (ch === "−" || ch === "–") {
                tokens.push({ type: "op", value: "-" });
                i++;
                continue;
            }
            if (ch === "(") {
                tokens.push({ type: "lparen" });
                i++;
                continue;
            }
            if (ch === ")") {
                tokens.push({ type: "rparen" });
                i++;
                continue;
            }
            if (ch === "," || ch === ";") {
                tokens.push({ type: "comma" });
                i++;
                continue;
            }

            // Any other character — not supported
            return null;
        }

        // Implicit multiplication insertion: 2pi, 2(3+4), (1+2)(3+4), 2sin(x), 90° cos(0) and `sqrt 16` support
        const expanded = [];
        for (let k = 0; k < tokens.length; k++) {
            const cur = tokens[k];
            if (expanded.length > 0) {
                const prev = expanded[expanded.length - 1];
                const prevIsVal = (prev.type === "num" || prev.type === "rparen"
                                   || (prev.type === "op" && (prev.value === "!" || prev.value === "°")));
                const curStartsVal = (cur.type === "num" || cur.type === "lparen" || cur.type === "func");
                if (prevIsVal && curStartsVal) {
                    expanded.push({ type: "op", value: "*" });
                }
            }
            expanded.push(cur);
        }

        return expanded;
    }

    // Recursive descent parser to evaluate tokens
    function _parseAndEval(tokens) {
        let pos = 0;

        function peek() {
            return pos < tokens.length ? tokens[pos] : null;
        }
        function consume() {
            return tokens[pos++];
        }

        // Expr := Term ( ('+' | '-') Term )*
        function parseExpr() {
            let left = parseTerm();
            while (peek() && peek().type === "op" && (peek().value === "+" || peek().value === "-")) {
                const op = consume().value;
                const right = parseTerm();
                left = (op === "+") ? (left + right) : (left - right);
            }
            return left;
        }

        // Term := Power ( ('*' | '/' | '%') Power )*
        function parseTerm() {
            let left = parseUnary();
            while (peek() && peek().type === "op" && (peek().value === "*" || peek().value === "/" || peek().value === "%")) {
                const op = consume().value;
                const right = parseUnary();
                if (op === "*") left = left * right;
                else if (op === "/") left = right === 0 ? NaN : left / right;
                else left = left % right;
            }
            return left;
        }

        // Unary := ('+' | '-') Unary | Power
        function parseUnary() {
            if (peek() && peek().type === "op" && (peek().value === "+" || peek().value === "-")) {
                const op = consume().value;
                const v = parseUnary();
                return op === "-" ? -v : v;
            }
            return parsePower();
        }

        // Power := Postfix ( '^' Unary )?   (right-associative)
        function parsePower() {
            let base = parsePostfix();
            if (peek() && peek().type === "op" && peek().value === "^") {
                consume();
                const exp = parseUnary();
                base = Math.pow(base, exp);
            }
            return base;
        }

        // Postfix := Primary ( '!' | '°' )*
        function parsePostfix() {
            let val = parsePrimary();
            while (peek() && peek().type === "op" && (peek().value === "!" || peek().value === "°")) {
                const op = consume().value;
                if (op === "!") val = root._fact(val);
                else if (op === "°") val = val * Math.PI / 180.0;
            }
            return val;
        }

        // Primary := Number | '(' Expr ')' | Func '(' Args ')' | Func Primary
        function parsePrimary() {
            const t = peek();
            if (!t) return NaN;

            if (t.type === "num") {
                consume();
                return t.value;
            }

            if (t.type === "lparen") {
                consume();
                const val = parseExpr();
                if (peek() && peek().type === "rparen") {
                    consume();
                } else {
                    // Allow live calculation even before closing parenthesis is typed
                }
                return val;
            }

            if (t.type === "func") {
                const fn = consume().value;
                const args = [];
                if (peek() && peek().type === "lparen") {
                    consume(); // '('
                    if (!peek() || peek().type !== "rparen") {
                        args.push(parseExpr());
                        while (peek() && peek().type === "comma") {
                            consume();
                            args.push(parseExpr());
                        }
                    }
                    if (peek() && peek().type === "rparen") {
                        consume();
                    }
                } else {
                    // Notation without parentheses like `sqrt 16` or `√16` or `sin 30°`
                    args.push(parsePower());
                }
                return _applyFunc(fn, args);
            }

            return NaN;
        }

        function _applyFunc(fn, args) {
            if (args.length === 0) return NaN;
            const a = args[0];
            const b = args.length > 1 ? args[1] : undefined;

            switch (fn) {
            case "sin": return Math.sin(a);
            case "cos": return Math.cos(a);
            case "tan":
            case "tg": return Math.tan(a);
            case "cot":
            case "ctg": return 1.0 / Math.tan(a);
            case "sec": return 1.0 / Math.cos(a);
            case "csc": return 1.0 / Math.sin(a);
            case "asin": return Math.asin(a);
            case "acos": return Math.acos(a);
            case "atan":
            case "atg": return Math.atan(a);
            case "atan2": return b !== undefined ? Math.atan2(a, b) : NaN;
            case "sinh": return Math.sinh(a);
            case "cosh": return Math.cosh(a);
            case "tanh": return Math.tanh(a);
            case "sqrt": return a < 0 ? NaN : Math.sqrt(a);
            case "cbrt": return Math.cbrt(a);
            case "root": return b !== undefined ? Math.pow(b, 1.0 / a) : Math.sqrt(a);
            case "ln": return a <= 0 ? NaN : Math.log(a);
            case "lg":
            case "log10": return a <= 0 ? NaN : Math.log10(a);
            case "log2": return a <= 0 ? NaN : Math.log2(a);
            case "log":
                if (b !== undefined) {
                    return (a <= 0 || a === 1 || b <= 0) ? NaN : (Math.log(b) / Math.log(a));
                }
                return a <= 0 ? NaN : Math.log(a);
            case "exp": return Math.exp(a);
            case "abs": return Math.abs(a);
            case "floor": return Math.floor(a);
            case "ceil": return Math.ceil(a);
            case "round": return b !== undefined ? Number(a.toFixed(Math.max(0, Math.min(12, Math.round(b))))) : Math.round(a);
            case "trunc": return Math.trunc(a);
            case "sign": return Math.sign(a);
            case "deg": return a * 180.0 / Math.PI;
            case "rad": return a * Math.PI / 180.0;
            case "fact": return root._fact(a);
            case "min": return Math.min.apply(null, args);
            case "max": return Math.max.apply(null, args);
            case "gcd": return b !== undefined ? root._gcd(a, b) : a;
            case "lcm": return b !== undefined ? root._lcm(a, b) : a;
            case "ncr":
            case "comb": return b !== undefined ? root._ncr(a, b) : NaN;
            default: return NaN;
            }
        }

        const result = parseExpr();
        if (pos < tokens.length) return NaN;
        return result;
    }

    function _formatNumber(val) {
        if (!isFinite(val) || isNaN(val)) return "";
        // Remove floating point noise around 0 (e.g. sin(pi) = 1.22e-16 -> 0)
        if (Math.abs(val) < 1e-12) val = 0;
        // Round to 12 significant digits so 0.1 + 0.2 gives 0.3
        const clean = Math.abs(val) >= 1e12 || (Math.abs(val) > 0 && Math.abs(val) < 1e-6)
            ? val.toExponential(6).replace(/\.?0+e/, "e")
            : String(parseFloat(val.toPrecision(12)));
        return clean;
    }

    // Main calculation function for launcher search query
    function evaluate(rawQuery) {
        const empty = { valid: false, formatted: "", raw: 0, expr: "", extra: "" };
        if (!rawQuery) return empty;

        let q = rawQuery.trim();
        if (!q) return empty;

        const explicitEq = q.startsWith("=");
        if (explicitEq) q = q.slice(1).trim();
        // Also strip trailing '=' if user entered "2+2="
        if (q.endsWith("=")) q = q.slice(0, -1).trim();
        if (!q) return empty;

        // Tokenize expression (supporting decimal comma/dot, functions, and constants)
        const tokens = _tokenize(q);
        if (!tokens || tokens.length === 0) return empty;

        // Avoid triggering calculator accidentally on plain number "123" without '='
        // Require either '=' prefix or at least 1 operator / function / constant / >1 token
        const hasOpOrFunc = tokens.some(t => t.type === "op" || t.type === "func" || t.isConst === true);
        if (!explicitEq && !hasOpOrFunc && tokens.length < 2) {
            return empty;
        }

        const val = _parseAndEval(tokens);
        if (isNaN(val) || !isFinite(val)) return empty;

        const formatted = _formatNumber(val);
        if (!formatted) return empty;

        // Additional hint (HEX/BIN for integers or deg/rad)
        let extra = "";
        if (Number.isInteger(val) && Math.abs(val) >= 10 && Math.abs(val) <= 0xFFFFFFFF) {
            const intVal = Math.round(val);
            if (intVal >= 0) {
                extra = "0x" + intVal.toString(16).toUpperCase() + " · 0b" + intVal.toString(2);
            }
        }

        return {
            valid: true,
            formatted: formatted,
            raw: val,
            expr: q,
            extra: extra
        };
    }
}
