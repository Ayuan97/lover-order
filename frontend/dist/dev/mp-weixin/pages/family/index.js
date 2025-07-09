"use strict";
const common_vendor = require("../../common/vendor.js");
const api_auth = require("../../api/auth.js");
const api_family = require("../../api/family.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const isLoading = common_vendor.ref(true);
    const familyInfo = common_vendor.ref(null);
    const members = common_vendor.ref([]);
    const showFamilyModal = common_vendor.ref(false);
    const showLeaveConfirm = common_vendor.ref(false);
    const activeTab = common_vendor.ref("create");
    const createForm = common_vendor.ref({
      name: "",
      description: ""
    });
    const joinForm = common_vendor.ref({
      inviteCode: ""
    });
    const isCreating = common_vendor.ref(false);
    const isJoining = common_vendor.ref(false);
    const isLeaving = common_vendor.ref(false);
    const defaultAvatar = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiByeD0iMjAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjIwIiB5PSIyNiIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjE2IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+RpDwvdGV4dD4KPHN2Zz4=");
    const defaultFamilyAvatar = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=");
    common_vendor.onMounted(async () => {
      await loadFamilyInfo();
    });
    common_vendor.watch(showFamilyModal, (newVal) => {
      if (newVal) {
        createForm.value = { name: "", description: "" };
        joinForm.value = { inviteCode: "" };
        activeTab.value = "create";
      }
    });
    const closeFamilyModal = () => {
      showFamilyModal.value = false;
    };
    const loadFamilyInfo = async () => {
      try {
        isLoading.value = true;
        if (!api_family.FamilyService.hasFamily()) {
          console.log("用户未加入家庭");
          familyInfo.value = null;
          return;
        }
        const [family, memberList] = await Promise.all([
          api_family.FamilyService.getFamilyInfo(),
          api_family.FamilyService.getFamilyMembers(true)
          // 包含访客
        ]);
        familyInfo.value = family;
        members.value = memberList;
        console.log("家庭信息:", family);
        console.log("成员列表:", memberList);
      } catch (error) {
        console.error("加载家庭信息失败:", error);
        if (error.statusCode === 403 || error.statusCode === 400) {
          familyInfo.value = null;
          members.value = [];
        } else {
          common_vendor.index.showToast({
            title: "加载失败",
            icon: "error"
          });
        }
      } finally {
        isLoading.value = false;
      }
    };
    const getRoleText = (role) => {
      switch (role) {
        case "admin":
          return "管理员";
        case "member":
          return "成员";
        case "guest":
          return "访客";
        default:
          return "成员";
      }
    };
    const handleCreateFamily = async () => {
      if (!createForm.value.name.trim()) {
        common_vendor.index.showToast({
          title: "请输入家庭名称",
          icon: "none"
        });
        return;
      }
      try {
        isCreating.value = true;
        const family = await api_family.FamilyService.createFamily(createForm.value);
        console.log("创建家庭成功:", family);
        const currentUser = api_auth.AuthService.getCurrentUser();
        if (currentUser) {
          currentUser.family_id = family.id;
          common_vendor.index.setStorageSync("user_info", currentUser);
        }
        common_vendor.index.showToast({
          title: "创建成功",
          icon: "success"
        });
        showFamilyModal.value = false;
        await loadFamilyInfo();
      } catch (error) {
        console.error("创建家庭失败:", error);
        common_vendor.index.showToast({
          title: error.message || "创建失败",
          icon: "error"
        });
      } finally {
        isCreating.value = false;
      }
    };
    const handleJoinFamily = async () => {
      if (!joinForm.value.inviteCode.trim()) {
        common_vendor.index.showToast({
          title: "请输入邀请码",
          icon: "none"
        });
        return;
      }
      try {
        isJoining.value = true;
        const family = await api_family.FamilyService.joinFamily({
          invite_code: joinForm.value.inviteCode.trim()
        });
        console.log("加入家庭成功:", family);
        const currentUser = api_auth.AuthService.getCurrentUser();
        if (currentUser) {
          currentUser.family_id = family.id;
          common_vendor.index.setStorageSync("user_info", currentUser);
        }
        common_vendor.index.showToast({
          title: "加入成功",
          icon: "success"
        });
        showFamilyModal.value = false;
        await loadFamilyInfo();
      } catch (error) {
        console.error("加入家庭失败:", error);
        common_vendor.index.showToast({
          title: error.message || "加入失败",
          icon: "error"
        });
      } finally {
        isJoining.value = false;
      }
    };
    const handleLeaveFamily = async () => {
      try {
        isLeaving.value = true;
        await api_family.FamilyService.leaveFamily();
        console.log("退出家庭成功");
        const currentUser = api_auth.AuthService.getCurrentUser();
        if (currentUser) {
          currentUser.family_id = null;
          common_vendor.index.setStorageSync("user_info", currentUser);
        }
        common_vendor.index.showToast({
          title: "已退出家庭",
          icon: "success"
        });
        showLeaveConfirm.value = false;
        await loadFamilyInfo();
      } catch (error) {
        console.error("退出家庭失败:", error);
        common_vendor.index.showToast({
          title: error.message || "退出失败",
          icon: "error"
        });
      } finally {
        isLeaving.value = false;
      }
    };
    const goToGuestShare = () => {
      common_vendor.index.navigateTo({
        url: "/pages/guest/share"
      });
    };
    const manageRecipes = () => {
      common_vendor.index.navigateTo({
        url: "/pages/recipes/index"
      });
    };
    const viewOrders = () => {
      common_vendor.index.navigateTo({
        url: "/pages/orders/index"
      });
    };
    const showAddMember = () => {
      var _a;
      common_vendor.index.showModal({
        title: "邀请成员",
        content: `分享家庭邀请码给新成员：${(_a = familyInfo.value) == null ? void 0 : _a.invite_code}`,
        confirmText: "复制邀请码",
        success: (res) => {
          if (res.confirm) {
            copyInviteCode();
          }
        }
      });
    };
    const editFamilyInfo = () => {
      common_vendor.index.showToast({
        title: "功能开发中",
        icon: "none"
      });
    };
    const familyPrivacy = () => {
      common_vendor.index.showToast({
        title: "功能开发中",
        icon: "none"
      });
    };
    const familyNotification = () => {
      common_vendor.index.showToast({
        title: "功能开发中",
        icon: "none"
      });
    };
    const copyInviteCode = () => {
      var _a;
      if (!((_a = familyInfo.value) == null ? void 0 : _a.invite_code)) return;
      common_vendor.index.setClipboardData({
        data: familyInfo.value.invite_code,
        success: () => {
          common_vendor.index.showToast({
            title: "邀请码已复制",
            icon: "success"
          });
        }
      });
    };
    const formatJoinDate = (dateStr) => {
      const date = new Date(dateStr);
      const now = /* @__PURE__ */ new Date();
      const diffTime = now.getTime() - date.getTime();
      const diffDays = Math.floor(diffTime / (1e3 * 60 * 60 * 24));
      if (diffDays === 0) {
        return "今天加入";
      } else if (diffDays === 1) {
        return "昨天加入";
      } else if (diffDays < 30) {
        return `${diffDays}天前加入`;
      } else {
        return `${date.getMonth() + 1}/${date.getDate()} 加入`;
      }
    };
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: familyInfo.value
      }, familyInfo.value ? {
        b: familyInfo.value.avatar || defaultFamilyAvatar.value,
        c: common_vendor.t(members.value.length),
        d: common_vendor.t(familyInfo.value.name),
        e: common_vendor.t(familyInfo.value.description || "温馨的家庭"),
        f: common_vendor.t(familyInfo.value.invite_code),
        g: common_vendor.o(copyInviteCode),
        h: common_vendor.t(members.value.length)
      } : {}, {
        i: !familyInfo.value && !isLoading.value
      }, !familyInfo.value && !isLoading.value ? {
        j: common_vendor.o(($event) => showFamilyModal.value = true)
      } : {}, {
        k: familyInfo.value
      }, familyInfo.value ? {
        l: common_vendor.o(goToGuestShare),
        m: common_vendor.o(copyInviteCode),
        n: common_vendor.o(manageRecipes),
        o: common_vendor.o(viewOrders)
      } : {}, {
        p: familyInfo.value
      }, familyInfo.value ? {
        q: common_vendor.t(members.value.length),
        r: common_vendor.f(members.value, (member, k0, i0) => {
          return {
            a: member.avatar || defaultAvatar.value,
            b: common_vendor.t(getRoleText(member.role)),
            c: common_vendor.n(member.role),
            d: common_vendor.t(member.nickname),
            e: common_vendor.t(formatJoinDate(member.created_at)),
            f: member.id
          };
        }),
        s: common_vendor.o(showAddMember)
      } : {}, {
        t: familyInfo.value
      }, familyInfo.value ? {
        v: common_vendor.o(editFamilyInfo),
        w: common_vendor.o(familyPrivacy),
        x: common_vendor.o(familyNotification)
      } : {}, {
        y: familyInfo.value
      }, familyInfo.value ? {
        z: common_vendor.o(($event) => showLeaveConfirm.value = true)
      } : {}, {
        A: showFamilyModal.value
      }, showFamilyModal.value ? common_vendor.e({
        B: common_vendor.o(closeFamilyModal),
        C: activeTab.value === "create" ? 1 : "",
        D: common_vendor.o(($event) => activeTab.value = "create"),
        E: activeTab.value === "join" ? 1 : "",
        F: common_vendor.o(($event) => activeTab.value = "join"),
        G: activeTab.value === "create"
      }, activeTab.value === "create" ? {
        H: createForm.value.name,
        I: common_vendor.o(($event) => createForm.value.name = $event.detail.value),
        J: createForm.value.description,
        K: common_vendor.o(($event) => createForm.value.description = $event.detail.value),
        L: common_vendor.t(isCreating.value ? "创建中..." : "创建我的家庭"),
        M: !createForm.value.name.trim() || isCreating.value,
        N: common_vendor.o(handleCreateFamily)
      } : {}, {
        O: activeTab.value === "join"
      }, activeTab.value === "join" ? {
        P: joinForm.value.inviteCode,
        Q: common_vendor.o(($event) => joinForm.value.inviteCode = $event.detail.value),
        R: common_vendor.t(isJoining.value ? "加入中..." : "加入家庭"),
        S: !joinForm.value.inviteCode.trim() || isJoining.value,
        T: common_vendor.o(handleJoinFamily)
      } : {}, {
        U: common_vendor.o(() => {
        }),
        V: common_vendor.o(closeFamilyModal)
      }) : {}, {
        W: showLeaveConfirm.value
      }, showLeaveConfirm.value ? {
        X: common_vendor.o(($event) => showLeaveConfirm.value = false),
        Y: common_vendor.t(isLeaving.value ? "退出中..." : "确认退出"),
        Z: isLeaving.value,
        aa: common_vendor.o(handleLeaveFamily),
        ab: common_vendor.o(() => {
        }),
        ac: common_vendor.o(($event) => showLeaveConfirm.value = false)
      } : {});
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-cefcc54e"]]);
wx.createPage(MiniProgramPage);
