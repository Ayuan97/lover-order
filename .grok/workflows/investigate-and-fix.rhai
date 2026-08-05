let meta = #{
    name: "investigate-and-fix",
    description: "Investigate lover-order for real bugs, verify findings, then fix confirmed issues",
    when_to_use: "Scan backend + iOS for correctness bugs and API mismatches, verify, and apply fixes",
    phases: [
        #{ title: "Scan", detail: "parallel domain scanners over backend and iOS" },
        #{ title: "Verify", detail: "adversarial verification of each finding" },
        #{ title: "Fix", detail: "apply confirmed fixes in the shared workspace" },
        #{ title: "Report", detail: "summarize what was fixed and what remains" },
    ],
};

let findings_schema = #{
    "type": "object",
    "required": ["findings"],
    "properties": #{
        "findings": #{
            "type": "array",
            "maxItems": 6,
            "items": #{
                "type": "object",
                "required": ["file", "issue", "severity", "area"],
                "properties": #{
                    "file": #{ "type": "string" },
                    "issue": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "area": #{ "type": "string" },
                },
            },
        },
    },
};

let verdict_schema = #{
    "type": "object",
    "required": ["real", "reason", "evidence"],
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string" },
        "evidence": #{ "type": "string" },
    },
};

let fix_schema = #{
    "type": "object",
    "required": ["fixed", "files_changed", "summary", "notes"],
    "properties": #{
        "fixed": #{ "type": "boolean" },
        "files_changed": #{ "type": "array", "items": #{ "type": "string" } },
        "summary": #{ "type": "string" },
        "notes": #{ "type": "string" },
    },
};

let report_schema = #{
    "type": "object",
    "required": ["report_markdown"],
    "properties": #{
        "report_markdown": #{ "type": "string" },
    },
};

// --- Phase 1: Scan ----------------------------------------------------------
phase("Scan");
log("Scanning backend and iOS for concrete bugs...");

let scan_jobs = [];

let p0 = "";
p0 += "You are investigating the lover-order monorepo (workspace root). ";
p0 += "Focus ONLY on backend Go correctness bugs in backend/. ";
p0 += "Project: couples meal decision app. Backend is Go+Gin+GORM under backend/. ";
p0 += "Rules from CLAUDE.md: only GET/POST APIs under /api/v1; meal status machine planning->confirmed->completed (or cancelled); ";
p0 += "household-scoped data; Apple auth + JWT. ";
p0 += "MUST use tools: list_dir, grep, read_file. Also run: cd backend && go build ./... and go vet ./... if shell is available. ";
p0 += "Look for: compile errors, nil panics, wrong status transitions, missing household isolation, ";
p0 += "SQL/GORM bugs, incorrect error codes, race conditions in meal dishes, broken invite flow, upload path issues. ";
p0 += "Report at most 6 concrete findings as {file, issue, severity, area}. ";
p0 += "severity: critical|high|medium|low. area must be backend. ";
p0 += "Empty list is valid ONLY after you have read handlers/services and attempted build. ";
p0 += "Do NOT invent style nits or speculative issues — only real bugs with file paths.";
scan_jobs.push(#{
    prompt: p0,
    label: "scan:backend-correctness",
    capability_mode: "execute",
    output_schema: findings_schema,
});

let p1 = "";
p1 += "You are investigating the lover-order monorepo. Focus ONLY on iOS Swift correctness bugs in ios/LoverOrder/. ";
p1 += "Stack: SwiftUI + Combine, XcodeGen project.yml, APIClient talking to /api/v1. ";
p1 += "MUST use tools: list_dir, grep, read_file on Models/, Network/, Features/, App/. ";
p1 += "Look for: wrong Decoding keys vs backend JSON, force unwrap crashes, broken navigation, ";
p1 += "View calling API directly (should go ViewModel/Service), token refresh failures, ";
p1 += "state not updating after mutations, meal flow broken (planning/confirm/complete), ";
p1 += "photo upload issues, invite/join household bugs, Combine memory leaks that break UI. ";
p1 += "Report at most 6 concrete findings as {file, issue, severity, area}. ";
p1 += "severity: critical|high|medium|low. area must be ios. ";
p1 += "Empty list is valid ONLY after reading Models, Network services, and key ViewModels. ";
p1 += "Do NOT invent pure style nits — only real functional bugs with file paths.";
scan_jobs.push(#{
    prompt: p1,
    label: "scan:ios-correctness",
    capability_mode: "read-only",
    output_schema: findings_schema,
});

let p2 = "";
p2 += "You are investigating API contract mismatches between backend and iOS in lover-order. ";
p2 += "MUST use tools: read backend internal/api/*.go and service response shapes; ";
p2 += "read ios Models/*.swift and Network/Services/*.swift and APIClient.swift. ";
p2 += "Compare field names (json tags vs CodingKeys), path strings, request body fields, ";
p2 += "status enums (meal scene/mood/status), list response wrappers. ";
p2 += "Also check: endpoints documented in CLAUDE.md vs registered routes in main.go or router setup. ";
p2 += "Report at most 6 concrete mismatches as {file, issue, severity, area}. ";
p2 += "severity: critical|high|medium|low. area must be api-contract. ";
p2 += "file should be the client or server file that is wrong (prefer the side that should change). ";
p2 += "Empty list is valid ONLY after systematic comparison of models and key endpoints.";
scan_jobs.push(#{
    prompt: p2,
    label: "scan:api-contract",
    capability_mode: "read-only",
    output_schema: findings_schema,
});

let p3 = "";
p3 += "You are investigating auth, security, and data isolation bugs in lover-order. ";
p3 += "MUST read: backend/pkg/jwt, backend/pkg/apple, backend/internal/middleware, ";
p3 += "backend/internal/api/auth_handler.go, household_handler, meal/recipe handlers for IDOR. ";
p3 += "iOS: TokenStorage, AuthService, APIClient auth headers and refresh. ";
p3 += "Look for: missing auth on routes, household_id not checked (user can access other household data), ";
p3 += "JWT issues, refresh token handling bugs, invite code abuse, path traversal in uploads, ";
p3 += "dev auth left open in production paths. ";
p3 += "Report at most 6 concrete findings as {file, issue, severity, area}. ";
p3 += "severity: critical|high|medium|low. area must be security. ";
p3 += "Empty list is valid ONLY after reading middleware and checking handlers for household scoping.";
scan_jobs.push(#{
    prompt: p3,
    label: "scan:security",
    capability_mode: "read-only",
    output_schema: findings_schema,
});

let scan_results = parallel(scan_jobs);

let findings = [];
let allowed_areas = ["backend", "ios", "api-contract", "security"];
for r in scan_results {
    if r != () && r.success && r.output.findings != () {
        for f in r.output.findings {
            if f.file != () && f.issue != () && f.file != "" && f.issue != "" {
                let area_ok = false;
                for a in allowed_areas {
                    if f.area == a { area_ok = true; }
                }
                if area_ok {
                    findings.push(f);
                } else {
                    log("Dropped finding with invalid area: " + f.area);
                }
            }
        }
    }
}

// Cap findings before verify to keep agent budget sane
let MAX_FINDINGS = 12;
if findings.len() > MAX_FINDINGS {
    log("Truncating findings from " + findings.len().to_string() + " to " + MAX_FINDINGS.to_string());
    let capped = [];
    let idx = 0;
    for f in findings {
        if idx < MAX_FINDINGS {
            capped.push(f);
        }
        idx += 1;
    }
    findings = capped;
}

log("Scan produced " + findings.len().to_string() + " candidate findings");
if findings.len() == 0 {
    let empty_report = "# Investigate & Fix Report\n\nNo candidate findings after scan.\n";
    let path = write_scratch_file("report.md", empty_report);
    complete(#{ summary: "No findings.", confirmed: [], fixed: [], path: path });
}

// --- Phase 2: Verify --------------------------------------------------------
phase("Verify");
log("Adversarially verifying " + findings.len().to_string() + " findings...");

let vjobs = [];
let fi = 0;
for f in findings {
    let encoded = json_encode(f);
    let vp = "";
    vp += "Adversarially verify this alleged bug in the lover-order repo. ";
    vp += "Finding JSON: " + encoded + " ";
    vp += "You MUST independently read the cited file(s) with read_file/grep. ";
    vp += "Set real=true ONLY if you find concrete evidence the bug exists and is a real functional/security problem. ";
    vp += "Style preferences, missing tests alone, or speculative future issues are real=false. ";
    vp += "evidence must quote or paraphrase actual code you read (path + what is wrong). ";
    vp += "If the file path is wrong or the issue is already fixed, real=false.";
    vjobs.push(#{
        prompt: vp,
        label: "verify:" + fi.to_string(),
        capability_mode: "read-only",
        output_schema: verdict_schema,
    });
    fi += 1;
}

let verdicts = parallel(vjobs);

let confirmed = [];
let vi = 0;
for v in verdicts {
    if v != () && v.success && v.output.real == true
        && v.output.evidence != () && v.output.evidence != "" {
        confirmed.push(findings[vi]);
    }
    vi += 1;
}

log(confirmed.len().to_string() + "/" + findings.len().to_string() + " findings confirmed");
if confirmed.len() == 0 {
    let nofix = "# Investigate & Fix Report\n\n";
    nofix += findings.len().to_string() + " candidates scanned; none survived adversarial verification.\n";
    let path2 = write_scratch_file("report.md", nofix);
    complete(#{ summary: "No confirmed bugs.", confirmed: [], fixed: [], path: path2 });
}

// Cap fixes
let MAX_FIXES = 6;
if confirmed.len() > MAX_FIXES {
    log("Capping fixes from " + confirmed.len().to_string() + " to " + MAX_FIXES.to_string());
    let capped_c = [];
    let ci = 0;
    for f in confirmed {
        if ci < MAX_FIXES {
            capped_c.push(f);
        }
        ci += 1;
    }
    confirmed = capped_c;
}

// --- Phase 3: Fix -----------------------------------------------------------
phase("Fix");
log("Applying fixes for " + confirmed.len().to_string() + " confirmed issues...");

let fix_jobs = [];
let fxi = 0;
for f in confirmed {
    let encoded_f = json_encode(f);
    let fp = "";
    fp += "Fix this CONFIRMED bug in the lover-order workspace (edit files in place, no worktree). ";
    fp += "Bug JSON: " + encoded_f + " ";
    fp += "Rules from project CLAUDE.md: ";
    fp += "- API methods only GET/POST; no new Markdown docs; no TODO; comments only explain WHY; ";
    fp += "- All user-facing Chinese if you change UI strings; SwiftUI View must not call network directly; ";
    fp += "- Do not over-engineer; fix only this issue; do not generate seed/demo data. ";
    fp += "Steps: 1) read the file and related call sites; 2) apply minimal correct fix with search_replace/write; ";
    fp += "3) if backend Go, run cd backend && go build ./... to verify compile; ";
    fp += "4) return fixed=true only if you actually edited files and build (if Go) passes. ";
    fp += "files_changed: list of relative paths you modified. summary: what you did. notes: residual risk.";
    fix_jobs.push(#{
        prompt: fp,
        label: "fix:" + fxi.to_string(),
        capability_mode: "all",
        output_schema: fix_schema,
    });
    fxi += 1;
}

let fix_results = parallel(fix_jobs);

let fixed_items = [];
let fix_idx = 0;
for fr in fix_results {
    if fr != () && fr.success && fr.output.fixed == true {
        fixed_items.push(#{
            issue: confirmed[fix_idx],
            summary: fr.output.summary,
            files_changed: fr.output.files_changed,
            notes: fr.output.notes,
        });
    }
    fix_idx += 1;
}

log("Fixed " + fixed_items.len().to_string() + "/" + confirmed.len().to_string() + " issues");

// --- Phase 4: Report --------------------------------------------------------
phase("Report");

let report_prompt = "";
report_prompt += "Write a concise Chinese markdown investigation report for the lover-order project. ";
report_prompt += "Confirmed bugs (JSON): " + json_encode(confirmed) + " ";
report_prompt += "Fix results (JSON): " + json_encode(fixed_items) + " ";
report_prompt += "Structure: 1) 概述 2) 已确认问题列表 3) 已修复项与改动文件 4) 未修复/跳过 5) 建议后续. ";
report_prompt += "Be factual; do not invent files. Output report_markdown only.";

let report_agent = agent(report_prompt, #{
    label: "report",
    capability_mode: "read-only",
    output_schema: report_schema,
});

let report_md = "# Investigate & Fix Report\n\n";
if report_agent != () && report_agent.success && report_agent.output.report_markdown != () {
    report_md = report_agent.output.report_markdown;
} else {
    report_md += "Confirmed: " + confirmed.len().to_string() + "\n";
    report_md += "Fixed: " + fixed_items.len().to_string() + "\n";
}

let report_path = write_scratch_file("report.md", report_md);
complete(#{
    summary: "Confirmed " + confirmed.len().to_string() + ", fixed " + fixed_items.len().to_string(),
    confirmed_count: confirmed.len(),
    fixed_count: fixed_items.len(),
    confirmed: confirmed,
    fixed: fixed_items,
    path: report_path,
});
