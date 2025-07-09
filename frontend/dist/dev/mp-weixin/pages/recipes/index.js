"use strict";
const common_vendor = require("../../common/vendor.js");
const api_family = require("../../api/family.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const isLoading = common_vendor.ref(true);
    const hasFamily = common_vendor.ref(false);
    const recipes = common_vendor.ref([]);
    const defaultRecipeImage = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==");
    common_vendor.onMounted(async () => {
      await checkFamilyStatus();
    });
    const checkFamilyStatus = async () => {
      try {
        isLoading.value = true;
        hasFamily.value = api_family.FamilyService.hasFamily();
        if (hasFamily.value) {
          await loadRecipes();
        }
      } catch (error) {
        console.error("检查家庭状态失败:", error);
      } finally {
        isLoading.value = false;
      }
    };
    const loadRecipes = async () => {
      try {
        recipes.value = [];
      } catch (error) {
        console.error("加载菜谱失败:", error);
        common_vendor.index.showToast({
          title: "加载失败",
          icon: "error"
        });
      }
    };
    const goToFamily = () => {
      common_vendor.index.navigateTo({
        url: "/pages/family/index"
      });
    };
    const addRecipe = () => {
      common_vendor.index.navigateTo({
        url: "/pages/recipes/add"
      });
    };
    const viewRecipe = (recipe) => {
      common_vendor.index.navigateTo({
        url: `/pages/recipes/detail?id=${recipe.id}`
      });
    };
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: isLoading.value
      }, isLoading.value ? {} : !hasFamily.value ? {
        c: common_vendor.o(goToFamily)
      } : common_vendor.e({
        d: recipes.value.length === 0
      }, recipes.value.length === 0 ? {
        e: common_vendor.o(addRecipe)
      } : {
        f: common_vendor.f(recipes.value, (recipe, k0, i0) => {
          return {
            a: recipe.image || defaultRecipeImage.value,
            b: common_vendor.t(recipe.name),
            c: common_vendor.t(recipe.description || "暂无描述"),
            d: common_vendor.t(recipe.category_name),
            e: common_vendor.t(recipe.cooking_time),
            f: recipe.id,
            g: common_vendor.o(($event) => viewRecipe(recipe), recipe.id)
          };
        })
      }, {
        g: common_vendor.o(addRecipe)
      }), {
        b: !hasFamily.value
      });
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-88d925cc"]]);
wx.createPage(MiniProgramPage);
