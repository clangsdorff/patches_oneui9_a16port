.class final Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$removeBlueLightFilterWindow$1;
.super Ljava/lang/Object;

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field final synthetic this$0:Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;


# direct methods
.method constructor <init>(Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;)V
    .locals 0

    iput-object p1, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$removeBlueLightFilterWindow$1;->this$0:Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method


# virtual methods
.method public final run()V
    .locals 3

    iget-object p0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$removeBlueLightFilterWindow$1;->this$0:Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;

    iget-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mBLFView:Landroid/widget/FrameLayout;

    if-eqz v0, :cond_0

    iget-object v1, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->context:Landroid/content/Context;

    const-string v2, "window"

    invoke-virtual {v1, v2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/view/WindowManager;

    invoke-interface {v1, v0}, Landroid/view/WindowManager;->removeView(Landroid/view/View;)V

    const/4 v0, 0x0

    iput-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mBLFView:Landroid/widget/FrameLayout;

    :cond_0
    return-void
.end method
