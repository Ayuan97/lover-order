let meta = #{
    name: "usage-logic-polish",
    description: "按这一顿自由画布走查协作、用餐与历史记录，并核对项目指引",
    when_to_use: "根据用户明确的产品方向检查画布主线与实际入口",
    phases: [
        #{ title: "Walk", detail: "按使用任务走查代码路径" },
        #{ title: "Verify", detail: "对抗核验问题是否真实" },
        #{ title: "Fix", detail: "修复已确认的使用逻辑与文案" },
        #{ title: "Constitution", detail: "核对 AGENTS.md 与产品方向" },
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

// 产品方向（写入每个 agent，并要求读取项目指引）
let constitution = "";
constitution += "先完整读取 AGENTS.md 与 docs/product-flow.md，以用户明确的决定为产品方向依据。";
constitution += "1) 主体是这一顿的自由画布，可以自由添加内容，想吃的菜是核心内容。";
constitution += "2) 日常主要由用户和对象共同编辑；来客以临时身份加入同一张画布，共同完善这一顿。";
constitution += "3) 主线=打开画布 → 添加内容和菜 → 共同商量 → 决定吃什么 → 在家用餐 → 进入历史。";
constitution += "4) 历史直接承载吃过的菜、画布当时的样子、备注和多张图片；决定吃什么与结束用餐分开。";
constitution += "5) 弱化模式切换；菜谱与买菜清单服务当前画布。内部数据标签不能替代产品主线。";
constitution += "6) 当前入口以可达代码核验；目标与实现分开说明。未确定的身份认证和权限不补默认答案。";
constitution += "7) 只改用户授权范围；无要求不生成测试代码、不运行测试，不执行完整验收。文案直接自然。";

// --- Phase 1: Walk four usage tasks -----------------------------------------
phase("Walk");
log("按 4 条使用任务走查...");

let tasks = [
    #{
        id: "T1",
        name: "身份与进入当前画布",
        paths: "ios/LoverOrder/App/RootView.swift AppState.swift Features/Auth/ Features/Profile/InviteTicketView.swift",
        ask: "核对登录及长期协作关系怎样进入当前画布，失败如何重试，来客怎样临时加入；区分现有认证与尚未明确的产品权限。",
    },
    #{
        id: "T2",
        name: "主循环我们这顿",
        paths: "ios/LoverOrder/Features/Meal/MealCanvasView.swift MealNowView.swift MealNowViewModel.swift AddDishView ShoppingListView MealReviewView backend/internal/service/meal_service.go",
        ask: "核对自由内容、菜品与画布操作是否一致，双方协作、决定吃什么、结束用餐到历史是否接通；根据实际挂载入口找断点，不凭未调用视图判断。",
    },
    #{
        id: "T3",
        name: "来客参与同一画布",
        paths: "MealCanvasView MealNowView DiningHostView DiningGuestView DiningJoinView dining_service.go",
        ask: "核对临时参与身份、加入当前画布及共同编辑能力；停止参与和结束用餐要分清。来客仅有列表点菜时记录与目标的差距，不将其写成产品限制。",
    },
    #{
        id: "T4",
        name: "历史与辅助入口",
        paths: "MainTabView ProfileView MenuView HistoryView HistoryDetailView",
        ask: "核对历史是否承载菜、画布样子、备注和多图；菜谱与买菜是否服务当前画布，页面是否弱化模式选择。",
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
    // 核对产品指引
    phase("Constitution");
    let c0 = "";
    c0 += "核对 AGENTS.md 与 docs/product-flow.md 是否表达用户明确的画布方向；只有用户明确决定需要同步时才直接修正文档，不追加重复小节。";
    c0 += constitution;
    c0 += " 用 search_replace 最小改动。updated=true 仅当文件已写入。";
    let cr0 = agent(c0, #{ label: "constitution-empty", capability_mode: "all", output_schema: constitution_schema });
    let empty_md = "# 使用逻辑打磨报告\n\n走查无新增问题。已核对产品指引。\n";
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
    c1 += "核对 AGENTS.md 与 docs/product-flow.md；仅同步用户明确的产品决定，不把实现缺口写成限制，不追加重复小节。";
    c1 += constitution;
    c1 += " 最小改动 search_replace。";
    let cr1 = agent(c1, #{ label: "constitution-only", capability_mode: "all", output_schema: constitution_schema });
    let md1 = "# 使用逻辑打磨\n\n候选未通过对抗核验。已核对产品指引。\n";
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
    pm += "修复 lover-order 画布主线与临时参与的使用逻辑和文案。";
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
cp += "核对 AGENTS.md 与 docs/product-flow.md，只根据用户明确的决定修正文档，保持一份清楚一致的产品方向：";
cp += "这一顿自由画布、两人日常协作、来客同一画布、用餐结束与历史四类内容。";
cp += constitution;
cp += " 不推断新需求，不追加重复小节。updated=true 仅当实际修改文件。";
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
