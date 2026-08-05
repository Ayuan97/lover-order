let meta = #{
    name: "ux-fix-and-verify",
    description: "修复 ux-product-review 确认的产品闭环问题，并对抗性核验修复是否生效",
    when_to_use: "在产品 UX 审查之后落地修复并二次核验",
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
rules += "项目 lover-order iOS SwiftUI + Go 后端。";
rules += "规则：只改必要代码；中文 UI 文案；View 不直接发请求走 ViewModel/Service；";
rules += "仅 GET/POST API；注释只写 WHY；不写 Markdown 文档；不留 TODO；不过度设计。";
rules += "设计 token 用 Design/ 已有颜色字体。修改后若动后端需 go build ./...。";

// 已核验问题清单（来自 ux-product-review）
let issues_blob = "";
issues_blob += "O1 critical: 建家/加入成功后 refreshProfile try? 吞错，RootView 只认 currentUser.hasHousehold 不认 household，半状态死胡同。";
issues_blob += " 修: 成功乐观写 currentUser.householdId；Root 条件含 household!=nil；refresh 失败可见重试+刷新家庭状态。";
issues_blob += " | O2 high: HouseholdSetupView 无退出登录。修: 底部次要退出登录+重新同步。";
issues_blob += " | O3 high: 建家成功不展示邀请码。修: 成功后中间态展示 inviteCode/QR/分享或 sheet InviteTicketView。";
issues_blob += " | O4 high: 临时邀请码与 InviteTicketView 永久码不同步。修: 餐券/分享用当前展示的码，或明确双轨文案并让 QR 用同一 code。";
issues_blob += " | O5 medium: 扫码权限 denied 黑屏。修: 非 authorized 说明+去设置+手输。";
issues_blob += " | O6 medium: 退出家文案隐瞒解散。修: 仅自己时提示将解散这个家。";
issues_blob += " | M1 high: 评价可永久跳过首页无补评。修: 关闭后轻量 banner/以后再说；可再打开评价。";
issues_blob += " | M2 high: meal==nil 底栏仍可点空白。修: 未就绪禁用加菜/定下；失败可重试 toast。";
issues_blob += " | M3 high: confirm/complete 无防重入。修: isActing loading+disabled。";
issues_blob += " | M4 medium: 0 道菜可 complete。修: 客户端禁止；后端 Complete 校验 dishCount>0（若尚未）。";
issues_blob += " | M5 medium: 自定义菜购物清单空无 CTA。修: 空态提示并引导补食材/存菜单。";
issues_blob += " | M6 medium: 标题写死我们这顿；改心情竞态。修: 标题用 currentScene.label；改心情避免并行 load 覆盖。";
issues_blob += " | D1 critical: 仅 family 场景显示开聚餐。修: pair/family 均可开聚餐（或任意非 future）。";
issues_blob += " | D2 high: Host 不判 roomExpiresAt。修: 按过期时间判存活；过期提示重新开房。";
issues_blob += " | D3 high: Host 无菜列表/进行中态。修: 房间页显示菜与点菜人；有效 room 时首页「聚餐中·查看」。";
issues_blob += " | D4 high: 结束聚餐文案像散伙。修: 文案改为关闭点菜房间；客人区分关房。";
issues_blob += " | D5 medium: 扫码文案固定餐券。修: 聚餐扫码自定义提示。";
issues_blob += " | D6 medium: 重新选这顿不提示清房间。修: 有有效 room 时确认文案写明会结束点菜房间。";

// --- Phase 1: Fix (sequential journeys to avoid file races) ------------------
phase("Fix");
log("开始按旅程顺序修复...");

// Fix A: onboarding + scanner + invite
let pA = "";
pA += "你是 iOS/后端工程师，在 lover-order 工作区直接改代码修复 Onboarding 相关问题。";
pA += rules;
pA += " 必须修复 ID：O1 O2 O3 O4 O5 O6。";
pA += " 问题与修法：" + issues_blob;
pA += " 重点文件：ios/LoverOrder/Features/Auth/HouseholdSetupView.swift App/RootView.swift App/AppState.swift";
pA += " Features/Profile/ProfileView.swift InviteTicketView.swift Design/Components/QRScannerView.swift Models/User.swift";
pA += " 步骤：先 read_file/grep 确认现状，再 search_replace 最小改动。";
pA += " O1: submit 成功后更新 currentUser 的 householdId；RootView 进主页条件加上 household 已加载；半状态提供刷新。";
pA += " O3: 创建成功可设 showInviteAfterCreate 弹出 InviteTicketView 或内嵌展示码。";
pA += " O4: InviteTicketView 接受外部 code 参数，Profile 传入当前 inviteCode 状态。";
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
pB += " 必须修复 ID：M1 M2 M3 M4 M5 M6，以及与 MealNowView 相关的 D1 D6。";
pB += " 问题与修法：" + issues_blob;
pB += " 重点文件：Features/Meal/MealNowView.swift MealNowViewModel.swift MealReviewView.swift";
pB += " ShoppingListView.swift AddDishView.swift EmptyMealHint.swift";
pB += " 后端若需 M4：backend/internal/service/meal_service.go Complete 拒绝 0 道菜。";
pB += " 先 read 再改。D1: showFriendOrderingCard 不要仅限 family。";
pB += " D6: cancel 确认文案在 room 有效时提示会结束点菜房间。";
pB += " M3: ViewModel isActing，按钮 isLoading。M1: 关闭评价后仍可从 banner 进入。";
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
pC += "你是 iOS 工程师，在 lover-order 工作区修复聚餐房间体验问题（D2 D3 D4 D5；D1/D6 若未修好可补）。";
pC += rules;
pC += " 问题与修法：" + issues_blob;
pC += " 重点：DiningHostView.swift DiningGuestView.swift DiningJoinView.swift QRScannerView/扫码提示";
pC += " MealNowView 聚餐入口文案（进行中·查看房间号）；可 grep dining/current 是否 Host 应轮询。";
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

// 期望行为简述供核验
let expect = #{};
expect["O1"] = "建家/加入成功后即使用户能进主页：乐观 householdId 或 Root 认 household；profile 失败有重试/刷新";
expect["O2"] = "HouseholdSetupView 有退出登录入口";
expect["O3"] = "建家成功后展示邀请码或弹出餐券/分享";
expect["O4"] = "InviteTicketView QR/分享与当前展示的邀请码一致";
expect["O5"] = "扫码非授权时有说明/去设置，非纯黑屏";
expect["O6"] = "仅自己退出家时文案提示解散";
expect["M1"] = "关评价后首页仍有补评入口或 banner";
expect["M2"] = "meal 未就绪时加菜/定下禁用或有 toast，不空白 sheet";
expect["M3"] = "confirm/complete 有 isActing/loading 防重入";
expect["M4"] = "0 道菜不能 complete（客户端或后端）";
expect["M5"] = "购物清单空态有引导 CTA";
expect["M6"] = "标题跟场景；心情修改无明显覆盖竞态";
expect["D1"] = "非仅 family：pair 等场景也能开聚餐";
expect["D2"] = "Host 按 roomExpiresAt 判断过期";
expect["D3"] = "Host 房间页有菜列表或等价；进行中入口文案";
expect["D4"] = "结束聚餐文案表达关房间而非散伙吃完";
expect["D5"] = "聚餐扫码提示可区分于家庭餐券";
expect["D6"] = "有 room 时重新选这顿确认文案提及结束点菜房间";

let vjobs = [];
for id in check_ids {
    let exp = expect[id];
    let vp = "";
    vp += "对抗性核验：检查产品问题 " + id + " 是否已在代码中真正修复。";
    vp += " 期望行为：" + exp + " ";
    vp += " 原始问题清单：" + issues_blob + " ";
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
