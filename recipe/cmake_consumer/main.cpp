#include <pxr/usd/sdf/layer.h>
#include <pxr/usd/sdf/path.h>
#include <pxr/usd/usd/stage.h>
#include <pxr/usd/usdGeom/xform.h>

#include <cstdio>

int main()
{
    pxr::UsdStageRefPtr stage =
        pxr::UsdStage::CreateNew("consumer_roundtrip.usdc");
    if (stage == nullptr) {
        return 1;
    }
    pxr::UsdGeomXform::Define(stage, pxr::SdfPath("/World"));
    stage->GetRootLayer()->Save();

    pxr::UsdStageRefPtr reopened = pxr::UsdStage::Open("consumer_roundtrip.usdc");
    if (reopened == nullptr) {
        return 1;
    }
    const bool valid = reopened->GetPrimAtPath(pxr::SdfPath("/World")).IsValid();
    std::remove("consumer_roundtrip.usdc");
    return valid ? 0 : 1;
}
