let meta = #{
    name: "ux-fix-and-verify",
    description: "核对画布与历史的产品闭环，按用户授权修复并复核",
    when_to_use: "在产品审查之后按用户指定范围处理已确认的缺口",
    phases: [
        #{ title: "Fix", detail: "按旅程顺序修复，避免同文件冲突" },
        #{ title: "Verify", detail: "对抗核验每条修复是否真正闭环" },
        #{ title: "Report", detail: "中文修复与核验报告" },
    ],
};

let fix_schema = #{
    "type": "object",
    "required": ["fixed_ids", "files_changed", "summary", "notes"],
    "properties": #{
        "fixed_ids": #{ "type": "array", "items": #{ "type": "string" } },
        "files_changed": #{ "type": "array", "items": #{ "type": "string" } },
        "summary": #{ "type": "string" },
        "notes": #{ "type": "string" },
    },
};

let verdict_schema = #{
    "type": "object",
    "required": ["id", "fixed", "reason", "evidence"],
    "properties": #{
        "id": #{ "type": "string" },
        "fixed": #{ "type": "boolean" },
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

let rules = "";
rules += "项目 lover-order iOS SwiftUI + Go 后端。先读取 AGENTS.md 与 docs/product-flow.md。";
rules += "主体是这一顿自由画布：两人日常共同编辑，来客临时加入同一画布，吃完历史保存菜、画布样子、备注和多图。";
rules += "只改用户明确授权的缺口；核查清单不是已确认问题。未授权的画布同步、身份认证或权限变更只报告，不擅自实现。";
rules += "复用 Design/ 的颜色字体，保持 GET/POST 接口契约。无要求不生成测试代码、不运行测试，不做完整验收。";

// 按当前产品方向逐项核对，确认存在问题且获授权后才修改
let issues_blob = "";
issues_blob += "O1: 登录或加入长期协作关系后，资料刷新失败时仍有明确入口和重试，不困在半状态。";
issues_blob += " 按当前身份状态和 RootView 实际分支核对。";
issues_blob += " | O2: 身份引导可以退出登录并重新同步。";
issues_blob += " | O3: 邀请日常参与者的入口和结果清楚可达。";
issues_blob += " | O4: 邀请码显示、二维码和分享内容一致。";
issues_blob += " | O5: 相机未授权时有说明、设置或手输入口。";
issues_blob += " | O6: 退出长期协作关系前说明对资料访问的影响。";
issues_blob += " | M1: 历史直接承载菜、画布样子、备注和多图，核对已有内容与缺口。";
issues_blob += " | M2: 当前餐次未加载时，画布操作有明确等待或失败反馈。";
issues_blob += " | M3: 决定和结束用餐的按钮防止重复提交，且真实执行对应动作。";
issues_blob += " | M4: 画布内容、实际菜单、决定与完成状态一致；未明确的空白画布规则只报告。";
issues_blob += " | M5: 买菜清单作为辅助入口，缺少食材时如实解释。";
issues_blob += " | M6: 页面围绕当前这一顿的画布，弱化模式选择，不从内部场景值生成主要玩法。";
issues_blob += " | D1: 从当前这一顿邀请临时参与者，继续使用同一张画布。";
issues_blob += " | D2: 按现有接口核对参与有效期的反馈，不擅自确定产品时长。";
issues_blob += " | D3: 来客可以共同完善画布；核对当前点菜列表与目标的差距。";
issues_blob += " | D4: 停止临时参与和结束用餐有清楚区别。";
issues_blob += " | D5: 日常关系邀请和临时参与入口的扫码与输入提示准确。";
issues_blob += " | D6: 当前餐次操作影响临时参与资格时明确反馈，不无提示改变权限。";

// --- Phase 1: Fix (sequential journeys to avoid file races) ------------------
phase("Fix");
log("开始按旅程顺序修复...");

// Fix A: onboarding + scanner + invite
let pA = "";
pA += "你是 iOS/后端工程师，在 lover-order 工作区直接改代码修复 Onboarding 相关问题。";
pA += rules;
pA += " 逐项核对 ID：O1 O2 O3 O4 O5 O6，仅修复确实存在且获授权的问题。";
pA += " 产品核查项：" + issues_blob;
pA += " 重点文件：ios/LoverOrder/Features/Auth/HouseholdSetupView.swift App/RootView.swift App/AppState.swift";
pA += " Features/Profile/ProfileView.swift InviteTicketView.swift Design/Components/QRScannerView.swift Models/User.swift";
pA += " 步骤：先 read_file/grep 确认现状，再 search_replace 最小改动。";
pA += " O1: 核对 submit、身份状态和 RootView 真实入口，不重复修改已经成立的分支。";
pA += " O3: 核对当前邀请入口，不根据未挂载组件增加一套流程。";
pA += " O4: 核对当前展示码是否贯穿二维码与分享。";
pA += " 返回 fixed_ids 实际修好的 ID 列表、files_changed、summary、notes。";

let rA = agent(pA, #{
    label: "fix:onboarding",
    capability_mode: "all",
    output_schema: fix_schema,
});

let fixed_all = [];
let files_all = [];
let notes_all = [];
if rA != () && rA.success {
    if rA.output.fixed_ids != () {
        for id in rA.output.fixed_ids { fixed_all.push(id); }
    }
    if rA.output.files_changed != () {
        for f in rA.output.files_changed { files_all.push(f); }
    }
    if rA.output.summary != () { notes_all.push("onboarding: " + rA.output.summary); }
    if rA.output.notes != () { notes_all.push(rA.output.notes); }
    log("Onboarding fix done: " + json_encode(rA.output.fixed_ids));
} else {
    log("Onboarding fix agent failed");
}

// Fix B: meal-loop
let pB = "";
pB += "你是 iOS/后端工程师，在 lover-order 工作区直接改代码修复「这一顿」主闭环问题。";
pB += rules;
pB += " 逐项核对 ID：M1 M2 M3 M4 M5 M6，以及与 MealNowView 相关的 D1 D6；只修用户授权范围。";
pB += " 产品核查项：" + issues_blob;
pB += " 重点文件：Features/Meal/MealCanvasView.swift MealNowView.swift MealNowViewModel.swift MealReviewView.swift";
pB += " ShoppingListView.swift AddDishView.swift Features/History/HistoryDetailView.swift";
pB += " 后端核对 backend/internal/service/meal_service.go 与实际餐次状态，不新增未明确的产品规则。";
pB += " 先 read 再改。D1: 核对当前画布邀请入口与来客共同编辑的差距。";
pB += " D6: 当前餐次操作影响参与资格时说明结果。";
pB += " M3: 核对动作是否真的调用并防重入。M1: 核对历史四类内容，缺少授权时仅报告。";
pB += " 返回 fixed_ids、files_changed、summary、notes。";

let rB = agent(pB, #{
    label: "fix:meal-loop",
    capability_mode: "all",
    output_schema: fix_schema,
});

if rB != () && rB.success {
    if rB.output.fixed_ids != () {
        for id in rB.output.fixed_ids { fixed_all.push(id); }
    }
    if rB.output.files_changed != () {
        for f in rB.output.files_changed { files_all.push(f); }
    }
    if rB.output.summary != () { notes_all.push("meal: " + rB.output.summary); }
    log("Meal-loop fix done: " + json_encode(rB.output.fixed_ids));
} else {
    log("Meal-loop fix agent failed");
}

// Fix C: dining host/guest
let pC = "";
pC += "你是 iOS 工程师，核对临时参与体验（D2 D3 D4 D5 及 D1 D6），只修确实存在且获授权的问题。";
pC += rules;
pC += " 产品核查项：" + issues_blob;
pC += " 重点：DiningHostView.swift DiningGuestView.swift DiningJoinView.swift QRScannerView/扫码提示";
pC += " MealNowView 当前邀请入口与后端 dining/current，核对实际权限和回传；来客目标是共同编辑同一画布。";
pC += " D2: roomExpiresAt 判断；D3: Host 展示 dishes；D4: 关闭点菜房间文案；D5: 扫码提示可配置。";
pC += " 先 read 现状（可能前序 agent 已改 MealNowView），再最小补丁，勿回滚他人修复。";
pC += " 返回 fixed_ids、files_changed、summary、notes。";

let rC = agent(pC, #{
    label: "fix:dining",
    capability_mode: "all",
    output_schema: fix_schema,
});

if rC != () && rC.success {
    if rC.output.fixed_ids != () {
        for id in rC.output.fixed_ids { fixed_all.push(id); }
    }
    if rC.output.files_changed != () {
        for f in rC.output.files_changed { files_all.push(f); }
    }
    if rC.output.summary != () { notes_all.push("dining: " + rC.output.summary); }
    log("Dining fix done: " + json_encode(rC.output.fixed_ids));
} else {
    log("Dining fix agent failed");
}

log("Claimed fixes: " + fixed_all.len().to_string());

// --- Phase 2: Adversarial verify --------------------------------------------
phase("Verify");

let check_ids = [
    "O1", "O2", "O3", "O4", "O5", "O6",
    "M1", "M2", "M3", "M4", "M5", "M6",
    "D1", "D2", "D3", "D4", "D5", "D6",
];

// 产品核对项，实际缺口与授权范围须分别报告
let expect = #{};
expect["O1"] = "建立长期协作关系后能进入当前画布，资料刷新失败可重试";
expect["O2"] = "HouseholdSetupView 有退出登录入口";
expect["O3"] = "建家成功后展示邀请码或弹出餐券/分享";
expect["O4"] = "InviteTicketView QR/分享与当前展示的邀请码一致";
expect["O5"] = "扫码非授权时有说明/去设置，非纯黑屏";
expect["O6"] = "仅自己退出家时文案提示解散";
expect["M1"] = "历史承载菜、画布当时的样子、备注和多图；已有内容与缺口分清";
expect["M2"] = "meal 未就绪时加菜/定下禁用或有 toast，不空白 sheet";
expect["M3"] = "confirm/complete 有 isActing/loading 防重入";
expect["M4"] = "画布内容、真实菜单与餐次状态一致，不擅自确定空白画布规则";
expect["M5"] = "购物清单空态有引导 CTA";
expect["M6"] = "页面围绕当前画布，弱化模式选择";
expect["D1"] = "从当前画布邀请临时参与者";
expect["D2"] = "按现有接口核对参与有效期与反馈，不新增产品时长限制";
expect["D3"] = "来客共同完善同一画布，目标与当前点菜列表差距如实报告";
expect["D4"] = "停止临时参与和结束用餐的反馈清楚";
expect["D5"] = "扫码和手输准确区分日常关系邀请与临时参与";
expect["D6"] = "影响临时参与资格的操作有明确反馈";

let vjobs = [];
for id in check_ids {
    let exp = expect[id];
    let vp = "";
    vp += "对抗性核验：检查产品问题 " + id + " 是否已在代码中真正修复。";
    vp += " 期望行为：" + exp + " ";
    vp += " 产品核查项：" + issues_blob + " ";
    vp += " 必须用 read_file/grep 读 ios/LoverOrder 与相关 backend 现状，禁止凭记忆。";
    vp += " fixed=true 仅当代码明确实现期望且用户路径可走通；部分修或仍有洞 → fixed=false。";
    vp += " evidence 引用文件路径与关键逻辑。返回 id=" + id + "。";
    vjobs.push(#{
        prompt: vp,
        label: "verify:" + id,
        capability_mode: "read-only",
        output_schema: verdict_schema,
    });
}

let verdicts = parallel(vjobs);

let passed = [];
let failed = [];
for v in verdicts {
    if v != () && v.success && v.output != () {
        if v.output.fixed == true && v.output.evidence != () && v.output.evidence != "" {
            passed.push(v.output);
        } else {
            failed.push(v.output);
        }
    }
}

log("Verify passed " + passed.len().to_string() + " failed " + failed.len().to_string());

// 若有失败，再开一轮补修（仅 failed ids）
if failed.len() > 0 {
    log("补修未通过项...");
    let fail_ids = [];
    let fail_detail = "";
    for f in failed {
        if f.id != () {
            fail_ids.push(f.id);
            fail_detail += f.id + ": " + f.reason + " | ";
        }
    }
    let pR = "";
    pR += "补修未通过对抗核验的 UX 问题。";
    pR += rules;
    pR += " 失败项：" + fail_detail;
    pR += " 全量期望与问题：" + issues_blob;
    pR += " 只修这些 ID：" + json_encode(fail_ids);
    pR += " 先 read 再改，最小补丁，勿破坏已通过的修复。";
    pR += " 返回 fixed_ids、files_changed、summary、notes。";
    let rR = agent(pR, #{
        label: "fix:retry",
        capability_mode: "all",
        output_schema: fix_schema,
    });
    if rR != () && rR.success {
        if rR.output.fixed_ids != () {
            for id in rR.output.fixed_ids { fixed_all.push(id); }
        }
        if rR.output.files_changed != () {
            for f in rR.output.files_changed { files_all.push(f); }
        }
        notes_all.push("retry: " + rR.output.summary);
    }

    // 对失败项再核验一轮
    let vjobs2 = [];
    for f in failed {
        let id2 = f.id;
        if id2 == () { id2 = "?"; }
        let exp2 = "";
        if expect[id2] != () { exp2 = expect[id2]; }
        let vp2 = "";
        vp2 += "再次对抗核验 " + id2 + " 是否已修复。期望：" + exp2 + " ";
        vp2 += " 必须读代码。fixed=true 仅当真正修好。id 字段填 " + id2;
        vjobs2.push(#{
            prompt: vp2,
            label: "reverify:" + id2,
            capability_mode: "read-only",
            output_schema: verdict_schema,
        });
    }
    let verdicts2 = parallel(vjobs2);
    // 重建 passed/failed
    let passed2 = [];
    let failed2 = [];
    // 保留原先已通过的
    for p in passed { passed2.push(p); }
    for v in verdicts2 {
        if v != () && v.success && v.output != () {
            if v.output.fixed == true && v.output.evidence != () && v.output.evidence != "" {
                passed2.push(v.output);
            } else {
                failed2.push(v.output);
            }
        }
    }
    passed = passed2;
    failed = failed2;
    log("After retry: passed " + passed.len().to_string() + " failed " + failed.len().to_string());
}

// --- Phase 3: Report --------------------------------------------------------
phase("Report");

let rp = "";
rp += "写中文 Markdown 报告：lover-order UX 修复与对抗核验结果。";
rp += " 修复代理笔记：" + json_encode(notes_all);
rp += " 改动文件：" + json_encode(files_all);
rp += " 核验通过：" + json_encode(passed);
rp += " 仍未通过：" + json_encode(failed);
rp += " 结构：1概述 2已修复且通过核验 3仍未通过 4改动文件 5残余风险。";
rp += " 只依据给定 JSON，不臆造。输出 report_markdown。";

let report_agent = agent(rp, #{
    label: "report",
    capability_mode: "read-only",
    output_schema: report_schema,
});

let report_md = "# UX 修复与对抗核验报告\n\n";
if report_agent != () && report_agent.success && report_agent.output.report_markdown != () {
    report_md = report_agent.output.report_markdown;
} else {
    report_md += "passed=" + passed.len().to_string() + " failed=" + failed.len().to_string() + "\n";
}

let path = write_scratch_file("report.md", report_md);
complete(#{
    summary: "passed " + passed.len().to_string() + " / failed " + failed.len().to_string(),
    passed_count: passed.len(),
    failed_count: failed.len(),
    passed: passed,
    failed: failed,
    files_changed: files_all,
    path: path,
});
