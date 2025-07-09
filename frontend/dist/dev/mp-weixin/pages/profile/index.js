"use strict";
const common_vendor = require("../../common/vendor.js");
const api_auth = require("../../api/auth.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const userInfo = common_vendor.ref({
      nickname: "",
      avatar: "",
      role: "member"
    });
    const defaultAvatar = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iNjAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjYwIiB5PSI3NSIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQ4IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+RpDwvdGV4dD4KPHN2Zz4=");
    const menuItems = [
      {
        id: 1,
        name: "家庭管理",
        icon: "👨‍👩‍👧‍👦",
        action: "family"
      },
      {
        id: 2,
        name: "访客分享演示",
        icon: "🎁",
        action: "guest-demo",
        badge: "NEW"
      },
      {
        id: 3,
        name: "我的收藏",
        icon: "❤️",
        action: "favorites"
      },
      {
        id: 4,
        name: "设置",
        icon: "⚙️",
        action: "settings"
      },
      {
        id: 5,
        name: "关于",
        icon: "ℹ️",
        action: "about"
      }
    ];
    common_vendor.onMounted(async () => {
      await loadUserInfo();
    });
    const loadUserInfo = async () => {
      try {
        const localUserInfo = api_auth.AuthService.getCurrentUser();
        console.log("本地用户信息:", localUserInfo);
        if (localUserInfo) {
          userInfo.value = {
            nickname: localUserInfo.nickname || "",
            avatar: localUserInfo.avatar || "",
            role: localUserInfo.role || "member"
          };
        }
        if (api_auth.AuthService.isLoggedIn()) {
          const serverUserInfo = await api_auth.AuthService.getUserProfile();
          console.log("服务器用户信息:", serverUserInfo);
          userInfo.value = {
            nickname: serverUserInfo.nickname || "",
            avatar: serverUserInfo.avatar || "",
            role: serverUserInfo.role || "member"
          };
          console.log("设置的用户信息:", userInfo.value);
        }
      } catch (error) {
        console.error("获取用户信息失败:", error);
        userInfo.value = {
          nickname: "未登录用户",
          avatar: "",
          role: "member"
        };
      }
    };
    const handleAvatarError = () => {
      console.log("头像加载失败，使用默认头像");
    };
    const getRoleText = (role) => {
      switch (role) {
        case "admin":
          return "家庭管理员";
        case "member":
          return "家庭成员";
        case "guest":
          return "访客";
        default:
          return "家庭成员";
      }
    };
    const handleMenuClick = (item) => {
      switch (item.action) {
        case "family":
          common_vendor.index.navigateTo({
            url: "/pages/family/index"
          });
          break;
        case "guest-demo":
          common_vendor.index.navigateTo({
            url: "/pages/demo/guest-flow"
          });
          break;
        case "favorites":
          common_vendor.index.navigateTo({
            url: "/pages/favorites/index"
          });
          break;
        case "settings":
          common_vendor.index.navigateTo({
            url: "/pages/settings/index"
          });
          break;
        case "about":
          common_vendor.index.navigateTo({
            url: "/pages/about/index"
          });
          break;
        default:
          common_vendor.index.showToast({
            title: "功能开发中",
            icon: "none"
          });
      }
    };
    return (_ctx, _cache) => {
      return {
        a: userInfo.value.avatar || defaultAvatar.value,
        b: common_vendor.o(handleAvatarError),
        c: common_vendor.t(userInfo.value.nickname || "未设置昵称"),
        d: common_vendor.t(getRoleText(userInfo.value.role)),
        e: common_vendor.f(menuItems, (item, k0, i0) => {
          return {
            a: common_vendor.t(item.icon),
            b: common_vendor.t(item.name),
            c: item.id,
            d: common_vendor.o(($event) => handleMenuClick(item), item.id)
          };
        })
      };
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-f97f9319"]]);
wx.createPage(MiniProgramPage);
