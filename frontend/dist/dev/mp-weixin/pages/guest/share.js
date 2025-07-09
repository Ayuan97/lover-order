"use strict";
const common_vendor = require("../../common/vendor.js");
const api_family = require("../../api/family.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "share",
  setup(__props) {
    const familyInfo = common_vendor.ref(null);
    const currentInvite = common_vendor.ref(null);
    const inviteHistory = common_vendor.ref([]);
    const isCreating = common_vendor.ref(false);
    const inviteNote = common_vendor.ref("");
    const selectedExpireIndex = common_vendor.ref(0);
    const expireOptions = common_vendor.ref([
      { label: "1小时", value: 1 },
      { label: "3小时", value: 3 },
      { label: "6小时", value: 6 },
      { label: "12小时", value: 12 },
      { label: "1天", value: 24 },
      { label: "3天", value: 72 },
      { label: "7天", value: 168 }
    ]);
    const recipeCount = common_vendor.ref(0);
    const memberCount = common_vendor.ref(0);
    const defaultFamilyAvatar = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=");
    common_vendor.onMounted(async () => {
      await loadPageData();
    });
    const loadPageData = async () => {
      try {
        if (!api_family.FamilyService.hasFamily()) {
          common_vendor.index.showToast({
            title: "请先加入家庭",
            icon: "none"
          });
          common_vendor.index.navigateBack();
          return;
        }
        const [family, stats, invites] = await Promise.all([
          api_family.FamilyService.getFamilyInfo(),
          api_family.FamilyService.getFamilyStats(),
          api_family.FamilyService.getGuestInvites()
        ]);
        familyInfo.value = family;
        recipeCount.value = stats.recipe_count;
        memberCount.value = stats.member_count;
        const activeInvite = invites.find((invite) => invite.is_active);
        currentInvite.value = activeInvite || null;
        inviteHistory.value = invites.filter((invite) => !invite.is_active).slice(0, 5);
      } catch (error) {
        console.error("加载页面数据失败:", error);
        common_vendor.index.showToast({
          title: "加载失败",
          icon: "error"
        });
      }
    };
    const onExpireChange = (e) => {
      selectedExpireIndex.value = e.detail.value;
    };
    const createInvite = async () => {
      try {
        isCreating.value = true;
        const params = {
          note: inviteNote.value.trim() || void 0,
          expires_hours: expireOptions.value[selectedExpireIndex.value].value
        };
        const invite = await api_family.FamilyService.createGuestInvite(params);
        currentInvite.value = invite;
        common_vendor.index.showToast({
          title: "邀请创建成功",
          icon: "success"
        });
        inviteNote.value = "";
      } catch (error) {
        console.error("创建邀请失败:", error);
        common_vendor.index.showToast({
          title: error.message || "创建失败",
          icon: "error"
        });
      } finally {
        isCreating.value = false;
      }
    };
    const copyInviteCode = () => {
      if (!currentInvite.value) return;
      common_vendor.index.setClipboardData({
        data: currentInvite.value.invite_code,
        success: () => {
          common_vendor.index.showToast({
            title: "邀请码已复制",
            icon: "success"
          });
        }
      });
    };
    const shareInvite = () => {
      if (!currentInvite.value || !familyInfo.value) return;
      const shareText = api_family.FamilyService.generateShareText(
        familyInfo.value.name,
        currentInvite.value.invite_code
      );
      common_vendor.index.share({
        provider: "weixin",
        scene: "WXSceneSession",
        type: 0,
        title: `${familyInfo.value.name} 邀请您品尝美味`,
        summary: shareText,
        success: () => {
          common_vendor.index.showToast({
            title: "分享成功",
            icon: "success"
          });
        },
        fail: () => {
          common_vendor.index.setClipboardData({
            data: shareText,
            success: () => {
              common_vendor.index.showToast({
                title: "分享内容已复制",
                icon: "success"
              });
            }
          });
        }
      });
    };
    const revokeInvite = () => {
      if (!currentInvite.value) return;
      common_vendor.index.showModal({
        title: "撤销邀请",
        content: "确定要撤销当前邀请吗？撤销后邀请码将立即失效。",
        success: async (res) => {
          if (res.confirm) {
            try {
              common_vendor.index.showToast({
                title: "邀请已撤销",
                icon: "success"
              });
              await loadPageData();
            } catch (error) {
              common_vendor.index.showToast({
                title: "撤销失败",
                icon: "error"
              });
            }
          }
        }
      });
    };
    const formatDate = (dateStr) => {
      const date = new Date(dateStr);
      return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, "0")}`;
    };
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: familyInfo.value
      }, familyInfo.value ? {
        b: familyInfo.value.avatar || defaultFamilyAvatar.value,
        c: common_vendor.t(familyInfo.value.name),
        d: common_vendor.t(familyInfo.value.description || "温馨家庭料理"),
        e: common_vendor.t(recipeCount.value),
        f: common_vendor.t(memberCount.value)
      } : {}, {
        g: common_vendor.t(expireOptions.value[selectedExpireIndex.value].label),
        h: selectedExpireIndex.value,
        i: expireOptions.value,
        j: common_vendor.o(onExpireChange),
        k: inviteNote.value,
        l: common_vendor.o(($event) => inviteNote.value = $event.detail.value),
        m: currentInvite.value
      }, currentInvite.value ? {
        n: common_vendor.t(currentInvite.value.is_active ? "有效" : "已失效"),
        o: currentInvite.value.is_active ? 1 : "",
        p: common_vendor.t(currentInvite.value.invite_code),
        q: common_vendor.o(copyInviteCode),
        r: common_vendor.t(formatDate(currentInvite.value.expires_at)),
        s: common_vendor.t(currentInvite.value.used_count),
        t: common_vendor.o(shareInvite),
        v: common_vendor.o(revokeInvite)
      } : {}, {
        w: !currentInvite.value || !currentInvite.value.is_active
      }, !currentInvite.value || !currentInvite.value.is_active ? {
        x: common_vendor.t(isCreating.value ? "创建中..." : "创建邀请"),
        y: isCreating.value,
        z: common_vendor.o(createInvite)
      } : {}, {
        A: inviteHistory.value.length > 0
      }, inviteHistory.value.length > 0 ? {
        B: common_vendor.f(inviteHistory.value, (invite, k0, i0) => {
          return common_vendor.e({
            a: common_vendor.t(invite.invite_code),
            b: invite.note
          }, invite.note ? {
            c: common_vendor.t(invite.note)
          } : {}, {
            d: common_vendor.t(formatDate(invite.created_at)),
            e: common_vendor.t(invite.is_active ? "有效" : "已失效"),
            f: invite.is_active ? 1 : "",
            g: common_vendor.t(invite.used_count),
            h: invite.id
          });
        })
      } : {});
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-5c837140"]]);
wx.createPage(MiniProgramPage);
