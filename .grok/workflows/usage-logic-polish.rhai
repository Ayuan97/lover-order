let meta = #{
    name: "usage-logic-polish",
    description: "按情侣日常主路径走查使用逻辑与人话，核验后修复，并写入产品宪法要点",
    when_to_use: "产品心智纠正后，冻结使用逻辑并打磨主路径/聚会弱入口",
    phases: [
        #{ title: "Walk", detail: "按使用任务走查代码路径" },
        #{ title: "Verify", detail: "对抗核验问题是否真实" },
        #{ title: "Fix", detail: "修复已确认的使用逻辑与文案" },
        #{ title: "Constitution", detail: "把产品宪法写入 CLAUDE.md" },
        #{ title: "Report", detail: "中文结果报告" },
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
                "required": ["id", "path", "file", "issue", "severity", "fix_hint"],
                "properties": #{
                    "id": #{ "type": "string" },
                    "path": #{ "type": "string" },
                    "file": #{ "type": "string" },
                    "issue": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "fix_hint": #{ "type": "string" },
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

let constitution_schema = #{
    "type": "object",
    "required": ["updated", "summary"],
    "properties": #{
        "updated": #{ "type": "boolean" },
        "summary": #{ "type": "string" },
    },
};

let report_schema = #{
    "type": "object",
    "required": ["report_markdown"],
    "properties": #{
        "report_markdown": #{ "type": "string" },
    },
};

// 产品宪法（写入每个 agent，禁止再做成三场景）
let constitution = "";
constitution += "lover-order 产品宪法：";
constitution += "1) 主产品=情侣日常「我们这顿」，首页固定 pair，不做三场景并列切换。";
constitution += "2) 主循环=点菜 → 就这些(confirm) → 吃完了(complete) → 可选写两句；禁止跳步；至少一道菜。";
constitution += "3) 聚会=偶发「点菜房间」，弱入口，不是模式/场景；关房间≠吃完。";
constitution += "4) 进家(餐券)≠进房间(房间号)；客人点菜不加入 household。";
constitution += "5) 以后想吃/菜单/记录=支线，不上首页抢主路径。";
constitution += "6) 文案要人话口语，禁止 AI 腔、说明书腔、教程式芯片。";
constitution += "7) 技术：View 不直接请求；API 仅 GET/POST；注释只写 WHY；不写新 Markdown 文档除 CLAUDE.md。";

// --- Phase 1: Walk four usage tasks -----------------------------------------
phase("Walk");
log("按 4 条使用任务走查...");

let tasks = [
    #{
        id: "T1",
        name: "进门与建家",
        paths: "ios/LoverOrder/App/RootView.swift AppState.swift Features/Auth/ Features/Profile/InviteTicketView.swift",
        ask: "登录→无家→建家/进家→餐券→主页；半状态；蹭饭不建家。找走不通、逻辑错、仍像三场景/产品腔的文案。",
    },
    #{
        id: "T2",
        name: "主循环我们这顿",
        paths: "ios/LoverOrder/Features/Meal/MealNowView.swift MealNowViewModel.swift AddDishView ShoppingListView MealReviewView EmptyMealHint backend/internal/service/meal_service.go",
        ask: "挑菜→就这些→买/做→吃完了→写两句。状态机、空菜拦截、底栏、定了后布局、补评。找逻辑断点与假思考文案。",
    },
    #{
        id: "T3",
        name: "客人点菜房间",
        paths: "MealNowView diningQuietEntry DiningHostView DiningGuestView DiningJoinView dining_service.go",
        ask: "弱入口、开房关房、客人不入家、关房≠complete。找入口过强、语义混场景、逻辑洞。",
    },
    #{
        id: "T4",
        name: "支线不抢主",
        paths: "MainTabView ProfileView FuturePlansView MenuView HistoryView",
        ask: "以后想吃/菜单/记录是否抢首页；相处模式是否还在；文案是否还在卖三场景。",
    },
];

let walk_jobs = [];
for t in tasks {
    let p = "";
    p += "你是产品使用审查员，只关心「用户能不能顺着用」，不是视觉美工。";
    p += constitution;
    p += " 任务 " + t.id + "：" + t.name + "。";
    p += " 必读：" + t.paths + "。";
    p += " 审查点：" + t.ask + " ";
    p += " 必须 read_file/grep 实际代码，禁止凭记忆。";
    p += " 最多 6 条 findings：id(如 T2-1)、path(任务名)、file、issue、severity(critical|high|medium|low)、fix_hint。";
    p += " 空列表仅在读完且路径通畅后人话也干净时允许。";
    p += " 不要报纯偏好；要可修复的使用逻辑或明显假 AI 文案。";
    walk_jobs.push(#{
        prompt: p,
        label: "walk:" + t.id,
        capability_mode: "read-only",
        output_schema: findings_schema,
    });
}

let walk_results = parallel(walk_jobs);

let findings = [];
for r in walk_results {
    if r != () && r.success && r.output.findings != () {
        for f in r.output.findings {
            if f.file != () && f.issue != () && f.file != "" && f.issue != "" {
                findings.push(f);
            }
        }
    }
}

let MAX_F = 16;
if findings.len() > MAX_F {
    log("截断 findings " + findings.len().to_string() + " -> " + MAX_F.to_string());
    let capped = [];
    let i = 0;
    for f in findings {
        if i < MAX_F { capped.push(f); }
        i += 1;
    }
    findings = capped;
}

log("走查候选 " + findings.len().to_string());
if findings.len() == 0 {
    // 仍写宪法
    phase("Constitution");
    let c0 = "";
    c0 += "在 CLAUDE.md 的「产品理念」或合适小节追加「产品宪法（使用逻辑）」短列表（中文要点，不写长文）。";
    c0 += constitution;
    c0 += " 用 search_replace 最小改动。updated=true 仅当文件已写入。";
    let cr0 = agent(c0, #{ label: "constitution-empty", capability_mode: "all", output_schema: constitution_schema });
    let empty_md = "# 使用逻辑打磨报告\n\n走查无新增问题。已尝试写入产品宪法。\n";
    let path0 = write_scratch_file("report.md", empty_md);
    complete(#{ summary: "No findings; constitution attempted", confirmed: [], fixed: [], path: path0 });
}

// --- Phase 2: Verify --------------------------------------------------------
phase("Verify");
let vjobs = [];
let fi = 0;
for f in findings {
    let enc = json_encode(f);
    let vp = "";
    vp += "对抗核验此使用问题是否在代码中真实存在。Finding: " + enc + " ";
    vp += constitution + " ";
    vp += "必须独立 read_file。real=true 仅当有证据且影响使用逻辑或明显违宪/假 AI 文案。";
    vp += "证据写路径与逻辑摘要。";
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
log("确认 " + confirmed.len().to_string() + "/" + findings.len().to_string());

if confirmed.len() == 0 {
    phase("Constitution");
    let c1 = "";
    c1 += "在 CLAUDE.md 追加「产品宪法（使用逻辑）」简短要点。";
    c1 += constitution;
    c1 += " 最小改动 search_replace。";
    let cr1 = agent(c1, #{ label: "constitution-only", capability_mode: "all", output_schema: constitution_schema });
    let md1 = "# 使用逻辑打磨\n\n候选未通过对抗核验。已写产品宪法。\n";
    let p1 = write_scratch_file("report.md", md1);
    complete(#{ summary: "None confirmed", confirmed: [], path: p1 });
}

// --- Phase 3: Fix (grouped sequential to reduce conflicts) ------------------
phase("Fix");

// Split by path prefix roughly via agent batches: meal vs rest
let meal_ids = [];
let other_ids = [];
for f in confirmed {
    let is_meal = false;
    // simple contain checks
    let file_s = f.file;
    if file_s.contains("Meal") || file_s.contains("meal_") || file_s.contains("Dining") || file_s.contains("dining") {
        is_meal = true;
    }
    if is_meal {
        meal_ids.push(f);
    } else {
        other_ids.push(f);
    }
}

let fixed_all = [];
let files_all = [];

if other_ids.len() > 0 {
    let po = "";
    po += "修复 lover-order 使用逻辑/人话问题（非 Meal 主文件优先，避免冲突）。";
    po += constitution;
    po += " 问题 JSON：" + json_encode(other_ids);
    po += " 读代码后最小 search_replace。保持中文口语。返回 fixed、files_changed、summary、notes。";
    po += " fixed=true 仅当确实改了文件。";
    let ro = agent(po, #{ label: "fix:other", capability_mode: "all", output_schema: fix_schema });
    if ro != () && ro.success && ro.output.fixed == true {
        fixed_all.push(ro.output);
        if ro.output.files_changed != () {
            for x in ro.output.files_changed { files_all.push(x); }
        }
    }
}

if meal_ids.len() > 0 {
    let pm = "";
    pm += "修复 lover-order 主路径/聚会使用逻辑与人话。";
    pm += constitution;
    pm += " 问题 JSON：" + json_encode(meal_ids);
    pm += " 重点 MealNowView/ViewModel/Dining* / meal_service。最小改动。";
    pm += " 若后端需 go build。返回 fixed、files_changed、summary、notes。";
    let rm = agent(pm, #{ label: "fix:meal", capability_mode: "all", output_schema: fix_schema });
    if rm != () && rm.success && rm.output.fixed == true {
        fixed_all.push(rm.output);
        if rm.output.files_changed != () {
            for x in rm.output.files_changed { files_all.push(x); }
        }
    }
}

// --- Phase 4: Constitution --------------------------------------------------
phase("Constitution");
let cp = "";
cp += "更新 CLAUDE.md：在产品理念附近增加小节「产品宪法（使用逻辑）」，用短列表写清：";
cp += "情侣日常主轴、主循环动词、聚会弱入口、进家≠进房间、支线不上首页、人话。";
cp += constitution;
cp += " 不要删已有有用内容；不要写成长文。updated=true 当已写入。";
let cr = agent(cp, #{ label: "constitution", capability_mode: "all", output_schema: constitution_schema });

// --- Phase 5: Report --------------------------------------------------------
phase("Report");
let rp = "";
rp += "写中文 Markdown 报告：使用逻辑打磨结果。";
rp += " 确认问题：" + json_encode(confirmed);
rp += " 修复结果：" + json_encode(fixed_all);
rp += " 宪法：" + json_encode(cr);
rp += " 结构：1概述 2确认问题 3已修 4产品宪法 5建议真机任务 6残余。人话、不臆造。";
let ra = agent(rp, #{ label: "report", capability_mode: "read-only", output_schema: report_schema });

let report_md = "# 使用逻辑打磨报告\n\n";
if ra != () && ra.success && ra.output.report_markdown != () {
    report_md = ra.output.report_markdown;
}
let path = write_scratch_file("report.md", report_md);
complete(#{
    summary: "confirmed " + confirmed.len().to_string() + " fixed_batches " + fixed_all.len().to_string(),
    confirmed_count: confirmed.len(),
    confirmed: confirmed,
    fixed: fixed_all,
    files_changed: files_all,
    path: path,
});
