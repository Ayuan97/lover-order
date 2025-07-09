"use strict";
const common_vendor = require("../../common/vendor.js");
const api_family = require("../../api/family.js");
if (!Array) {
  const _component_uni_popup = common_vendor.resolveComponent("uni-popup");
  _component_uni_popup();
}
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const isLoading = common_vendor.ref(true);
    const isValidInvite = common_vendor.ref(false);
    const isGuestRegistered = common_vendor.ref(false);
    const isRegistering = common_vendor.ref(false);
    const inviteCode = common_vendor.ref("");
    const familyInfo = common_vendor.ref(null);
    const recipeCount = common_vendor.ref(0);
    const guestInfo = common_vendor.ref({
      nickname: "",
      phone: ""
    });
    const recipes = common_vendor.ref([]);
    const showInputInvite = common_vendor.ref(false);
    const inputInviteCode = common_vendor.ref("");
    const defaultFamilyAvatar = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=");
    const defaultRecipeImage = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==");
    common_vendor.onMounted(async () => {
      await initGuestPage();
    });
    common_vendor.watch(showInputInvite, (newVal) => {
      if (newVal) {
        inputInviteCode.value = "";
      }
    });
    const initGuestPage = async () => {
      try {
        isLoading.value = true;
        const pages = getCurrentPages();
        const currentPage = pages[pages.length - 1];
        const options = currentPage.options || {};
        inviteCode.value = options.invite || "";
        if (!inviteCode.value) {
          isValidInvite.value = false;
          return;
        }
        await checkInviteCode(inviteCode.value);
      } catch (error) {
        console.error("初始化访客页面失败:", error);
        isValidInvite.value = false;
      } finally {
        isLoading.value = false;
      }
    };
    const checkInviteCode = async (code) => {
      try {
        const inviteInfo = await api_family.FamilyService.checkGuestInvite(code);
        if (inviteInfo && inviteInfo.is_valid) {
          isValidInvite.value = true;
          familyInfo.value = inviteInfo.family;
          recipeCount.value = inviteInfo.recipe_count || 0;
          const guestToken = common_vendor.index.getStorageSync("guest_token");
          if (guestToken) {
            isGuestRegistered.value = true;
            await loadGuestData();
          }
        } else {
          isValidInvite.value = false;
        }
      } catch (error) {
        console.error("检查邀请码失败:", error);
        isValidInvite.value = false;
      }
    };
    const registerGuest = async () => {
      if (!guestInfo.value.nickname.trim()) {
        common_vendor.index.showToast({
          title: "请输入昵称",
          icon: "none"
        });
        return;
      }
      try {
        isRegistering.value = true;
        const params = {
          invite_code: inviteCode.value,
          user_info: {
            nickname: guestInfo.value.nickname.trim(),
            avatar_url: "",
            gender: 0
          }
        };
        const result = await api_family.FamilyService.guestRegister(params);
        common_vendor.index.setStorageSync("guest_token", result.token);
        common_vendor.index.setStorageSync("guest_info", result.guest_info);
        isGuestRegistered.value = true;
        await loadGuestData();
        common_vendor.index.showToast({
          title: "欢迎体验",
          icon: "success"
        });
      } catch (error) {
        console.error("注册访客失败:", error);
        common_vendor.index.showToast({
          title: error.message || "注册失败",
          icon: "error"
        });
      } finally {
        isRegistering.value = false;
      }
    };
    const loadGuestData = async () => {
      try {
        recipes.value = [];
      } catch (error) {
        console.error("加载访客数据失败:", error);
      }
    };
    const viewRecipe = (recipe) => {
      common_vendor.index.navigateTo({
        url: `/pages/guest/recipe-detail?id=${recipe.id}`
      });
    };
    const addToCart = (recipe) => {
      common_vendor.index.showToast({
        title: "已添加到购物车",
        icon: "success"
      });
    };
    const goBack = () => {
      common_vendor.index.navigateBack();
    };
    const checkInputInvite = async () => {
      if (!inputInviteCode.value.trim()) return;
      try {
        inviteCode.value = inputInviteCode.value.trim();
        showInputInvite.value = false;
        isLoading.value = true;
        await checkInviteCode(inviteCode.value);
      } catch (error) {
        console.error("检查邀请码失败:", error);
      } finally {
        isLoading.value = false;
      }
    };
    return (_ctx, _cache) => {
      var _a, _b, _c, _d;
      return common_vendor.e({
        a: isLoading.value
      }, isLoading.value ? {} : !isValidInvite.value ? {
        c: common_vendor.o(goBack),
        d: common_vendor.o(($event) => showInputInvite.value = true)
      } : !isGuestRegistered.value ? {
        f: ((_a = familyInfo.value) == null ? void 0 : _a.avatar) || defaultFamilyAvatar.value,
        g: common_vendor.t((_b = familyInfo.value) == null ? void 0 : _b.name),
        h: common_vendor.t(((_c = familyInfo.value) == null ? void 0 : _c.description) || "品尝温馨家庭料理"),
        i: common_vendor.t(recipeCount.value),
        j: guestInfo.value.nickname,
        k: common_vendor.o(($event) => guestInfo.value.nickname = $event.detail.value),
        l: guestInfo.value.phone,
        m: common_vendor.o(($event) => guestInfo.value.phone = $event.detail.value),
        n: common_vendor.t(isRegistering.value ? "注册中..." : "开始体验"),
        o: !guestInfo.value.nickname.trim() || isRegistering.value,
        p: common_vendor.o(registerGuest)
      } : common_vendor.e({
        q: common_vendor.t(guestInfo.value.nickname),
        r: common_vendor.t((_d = familyInfo.value) == null ? void 0 : _d.name),
        s: common_vendor.t(recipes.value.length),
        t: recipes.value.length > 0
      }, recipes.value.length > 0 ? {
        v: common_vendor.f(recipes.value, (recipe, k0, i0) => {
          return {
            a: recipe.image || defaultRecipeImage.value,
            b: common_vendor.t(recipe.name),
            c: common_vendor.t(recipe.price || "时价"),
            d: common_vendor.o(($event) => addToCart(), recipe.id),
            e: recipe.id,
            f: common_vendor.o(($event) => viewRecipe(recipe), recipe.id)
          };
        })
      } : {}), {
        b: !isValidInvite.value,
        e: !isGuestRegistered.value,
        w: common_vendor.o(($event) => showInputInvite.value = false),
        x: inputInviteCode.value,
        y: common_vendor.o(($event) => inputInviteCode.value = $event.detail.value),
        z: common_vendor.o(($event) => showInputInvite.value = false),
        A: !inputInviteCode.value.trim(),
        B: common_vendor.o(checkInputInvite),
        C: common_vendor.sr("inputInvitePopup", "f13b3607-0"),
        D: common_vendor.p({
          type: "center",
          ["mask-click"]: false
        })
      });
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-f13b3607"]]);
wx.createPage(MiniProgramPage);
