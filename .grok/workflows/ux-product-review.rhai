let meta = #{
    name: "ux-product-review",
    description: "从产品使用角度审查 lover-order 的 UI/UX 与功能逻辑闭环",
    when_to_use: "审查自由画布、日常与临时协作、用餐结束和历史记录的实际可用性",
    phases: [
        #{ title: "Review", detail: "按产品旅程并行审查" },
        #{ title: "Verify", detail: "对抗核验每个问题是否真实存在" },
        #{ title: "Report", detail: "输出中文产品审查报告" },
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
                "required": ["journey", "file", "issue", "user_impact", "severity", "suggestion"],
                "properties": #{
                    "journey": #{ "type": "string" },
                    "file": #{ "type": "string" },
                    "issue": #{ "type": "string" },
                    "user_impact": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "suggestion": #{ "type": "string" },
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

let report_schema = #{
    "type": "object",
    "required": ["report_markdown"],
    "properties": #{
        "report_markdown": #{ "type": "string" },
    },
};

// 产品背景（写入每个 prompt，子代理无会话上下文）
let product_ctx = "";
product_ctx += "先读取 AGENTS.md 与 docs/product-flow.md。产品主体是这一顿的自由画布，可自由添加内容，菜是核心内容。";
product_ctx += "主线：打开画布 → 添加内容和菜 → 共同编辑商量 → 决定今天吃什么 → 在家用餐 → 结束并进入历史。";
product_ctx += "日常主要用户和对象共同编辑；来客以临时身份加入同一画布，不能以独立点菜列表替代共同编辑。";
product_ctx += "历史承载菜、画布当时的样子、备注与多图。产品方向与当前实现须分开，内部场景标签不定义主要玩法。";
product_ctx += "iOS 主 Tab：这一顿 / 菜谱 / 记录 / 我的。代码在 ios/LoverOrder/。";
product_ctx += "复用现有设计 token。审查真实用户能否走通，仅静态检查，不生成测试代码、不运行测试。";

// 可选 scope：args.scope 限制旅程；默认全量
let scope = "all";
if args != () && args.scope != () && args.scope != "" {
    scope = args.scope;
}

// journey 定义：id, label, paths hint
let journeys = [];
if scope == "all" || scope == "onboarding" {
    journeys.push(#{
        id: "onboarding",
        label: "登录与建家/加入家",
        paths: "ios/LoverOrder/Features/Auth/ ios/LoverOrder/App/RootView.swift ios/LoverOrder/App/AppState.swift ios/LoverOrder/Features/Profile/InviteTicketView.swift",
        focus: "首次打开到进入主页；无家/有家；邀请码创建/加入/退出；失败与重试；是否卡在半状态",
    });
}
if scope == "all" || scope == "meal-loop" {
    journeys.push(#{
        id: "meal-loop",
        label: "这一顿画布到历史",
        paths: "ios/LoverOrder/Features/Meal/MealCanvasView.swift ios/LoverOrder/Features/Meal/MealNowView.swift ios/LoverOrder/Features/Meal/MealNowViewModel.swift ios/LoverOrder/Features/Meal/AddDishView.swift ios/LoverOrder/Features/Meal/MealReviewView.swift ios/LoverOrder/Features/Meal/ShoppingListView.swift",
        focus: "自由内容编辑、菜与画布操作一致性、双方协作、决定与结束用餐的可达入口、历史是否保存画布与多图；只以当前挂载页面判断行为",
    });
}
if scope == "all" || scope == "dining" {
    journeys.push(#{
        id: "dining",
        label: "临时来客共同编辑画布",
        paths: "ios/LoverOrder/Features/Meal/DiningHostView.swift ios/LoverOrder/Features/Meal/DiningGuestView.swift ios/LoverOrder/Features/Meal/DiningJoinView.swift ios/LoverOrder/Features/Meal/DiningDishPicker.swift ios/LoverOrder/Network/Services/DiningService.swift",
        focus: "临时身份加入当前这一顿，来客是否能进入同一画布共同编辑；参与结束与用餐完成是否区分；未确定的认证与权限记录为待明确",
    });
}
if scope == "all" || scope == "menu" {
    journeys.push(#{
        id: "menu",
        label: "菜谱资料与画布加菜",
        paths: "ios/LoverOrder/Features/Menu/ ios/LoverOrder/Features/Profile/CategoryManagementView.swift",
        focus: "菜谱创建和维护是否能服务当前画布加菜；收藏、分类与空态是否可用；菜谱变化后记录中的菜是否清楚",
    });
}
if scope == "all" || scope == "history-profile" {
    journeys.push(#{
        id: "history-profile",
        label: "记录与我的 回顾与家管理",
        paths: "ios/LoverOrder/Features/History/ ios/LoverOrder/Features/Profile/ ios/LoverOrder/App/MainTabView.swift",
        focus: "历史是否承载吃过的菜、画布当时的样子、备注与多图；资料及家庭关系管理是否清楚；从记录再吃一顿是否接通；权限和空态",
    });
}
if scope == "all" || scope == "feedback" {
    journeys.push(#{
        id: "feedback",
        label: "反馈闭环 加载错误空态与文案",
        paths: "ios/LoverOrder/Design/Components/ ios/LoverOrder/Network/APIClient.swift ios/LoverOrder/Network/APIError.swift ios/LoverOrder/App/ ios/LoverOrder/Features/",
        focus: "加载中/失败重试/无网络/业务错误文案是否人话；Toast 与阻断是否合适；关键操作是否有确认；状态机错误（如未 confirm 就 complete）用户是否懂下一步",
    });
}

if journeys.len() == 0 {
    pause("verification", "args.scope 无效。可用: all | onboarding | meal-loop | dining | menu | history-profile | feedback");
}

// --- Phase 1: Review --------------------------------------------------------
phase("Review");
log("产品旅程审查：scope=" + scope + " journeys=" + journeys.len().to_string());

let review_jobs = [];
for j in journeys {
    let p = "";
    p += "你是资深产品/UX 审查员，审查 iOS 应用 lover-order 的「真实使用问题」与「功能逻辑闭环」。";
    p += product_ctx;
    p += " 本次只审旅程：" + j.label + "（id=" + j.id + "）。";
    p += " 必读路径：" + j.paths + "。";
    p += " 关注点：" + j.focus + "。";
    p += " 必须用工具 list_dir/read_file/grep 读实际 SwiftUI 与 ViewModel/Service，禁止凭记忆编造。";
    p += " 从用户视角找：走不通的步骤、缺入口、状态不可见、文案误导、闭环断裂（做了 A 到不了 B）、死胡同、二次操作困难。";
    p += " 不要报纯视觉偏好（圆角/色值）除非严重影响可理解性；不要报未读代码就猜的性能问题。";
    p += " 最多 6 条 findings，字段：journey(用本旅程 id)、file(相对路径)、issue、user_impact、severity(critical|high|medium|low)、suggestion(可执行产品/交互建议)。";
    p += " 空列表仅在你读完相关主文件且确认闭环通畅后才允许。";
    review_jobs.push(#{
        prompt: p,
        label: "review:" + j.id,
        capability_mode: "read-only",
        output_schema: findings_schema,
    });
}

let review_results = parallel(review_jobs);

let findings = [];
let allowed = [];
for j in journeys {
    allowed.push(j.id);
}
for r in review_results {
    if r != () && r.success && r.output.findings != () {
        for f in r.output.findings {
            if f.file != () && f.issue != () && f.file != "" && f.issue != "" {
                let ok = false;
                for a in allowed {
                    if f.journey == a { ok = true; }
                }
                // 允许 journey 写中文 label 时回填 id：只要在 allowed 内；否则若 scope=all 仍收录但标记
                if !ok {
                    // 尝试宽松：空 journey 则丢弃
                    if f.journey == () || f.journey == "" {
                        log("Dropped finding without journey");
                    } else {
                        // 保留但 journey 保持原样（可能是误写）
                        findings.push(f);
                    }
                } else {
                    findings.push(f);
                }
            }
        }
    }
}

let MAX_FINDINGS = 18;
if findings.len() > MAX_FINDINGS {
    log("Truncating findings " + findings.len().to_string() + " -> " + MAX_FINDINGS.to_string());
    let capped = [];
    let idx = 0;
    for f in findings {
        if idx < MAX_FINDINGS { capped.push(f); }
        idx += 1;
    }
    findings = capped;
}

log("审查候选 " + findings.len().to_string() + " 条");
if findings.len() == 0 {
    let empty = "# lover-order 产品 UI/UX 审查报告\n\n未发现可报告的产品闭环问题（在已读代码范围内）。\n";
    let path = write_scratch_file("report.md", empty);
    complete(#{ summary: "No UX findings.", confirmed: [], path: path });
}

// --- Phase 2: Verify --------------------------------------------------------
phase("Verify");
log("核验 " + findings.len().to_string() + " 条产品问题...");

let vjobs = [];
let fi = 0;
for f in findings {
    let enc = json_encode(f);
    let vp = "";
    vp += "你是怀疑论者。核验这条「产品/UX/闭环」问题是否在代码里真实存在。";
    vp += " Finding JSON: " + enc + " ";
    vp += " 必须独立 read_file/grep 相关 Swift 文件；对照用户操作路径是否真断。";
    vp += " real=true 仅当：有具体代码证据证明用户会遇到该问题或逻辑缺口。";
    vp += " 纯审美偏好、臆测、已有替代入口但审查员没看见 → real=false。";
    vp += " evidence 须写出文件路径与关键交互/状态逻辑摘要。";
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
        let item = findings[vi];
        // 附上核验证据便于报告
        confirmed.push(#{
            journey: item.journey,
            file: item.file,
            issue: item.issue,
            user_impact: item.user_impact,
            severity: item.severity,
            suggestion: item.suggestion,
            evidence: v.output.evidence,
        });
    }
    vi += 1;
}

log(confirmed.len().to_string() + "/" + findings.len().to_string() + " 条通过核验");

// --- Phase 3: Report --------------------------------------------------------
phase("Report");

let rp = "";
rp += "根据已核验的产品问题，写一份中文 Markdown 审查报告（lover-order）。";
rp += " 产品理念：" + product_ctx + " ";
rp += " 已核验问题 JSON：" + json_encode(confirmed) + " ";
rp += " 未通过核验的不必展开。结构：";
rp += " 1) 概述（用户能不能完成核心闭环）";
rp += " 2) 按旅程分组的问题表（严重度/影响/证据/建议）";
rp += " 3) 逻辑闭环缺口汇总（哪一步到哪一步断了）";
rp += " 4) 优先修复排序（P0/P1/P2）";
rp += " 5) 做得好的闭环（如有，简短）";
rp += " 语气专业克制，不臆造未核验项。只输出 report_markdown。";

let report_agent = agent(rp, #{
    label: "report",
    capability_mode: "read-only",
    output_schema: report_schema,
});

let report_md = "# lover-order 产品 UI/UX 审查报告\n\n";
if report_agent != () && report_agent.success && report_agent.output.report_markdown != () {
    report_md = report_agent.output.report_markdown;
} else {
    report_md += "核验通过 " + confirmed.len().to_string() + " 条。\n\n";
    report_md += "```json\n" + json_encode(confirmed) + "\n```\n";
}

let report_path = write_scratch_file("report.md", report_md);
complete(#{
    summary: "Confirmed " + confirmed.len().to_string() + " product UX issues",
    confirmed_count: confirmed.len(),
    candidate_count: findings.len(),
    scope: scope,
    confirmed: confirmed,
    path: report_path,
});
