# SW blue light filter: a full screen, touch-through overlay tinted from sw_blf_color_array
.method public final setBlueLightFilter(ZI)V
    .locals 8

    if-eqz p1, :cond_off

    iget-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mBLFView:Landroid/widget/FrameLayout;

    if-nez v0, :cond_color

    new-instance v2, Landroid/view/WindowManager$LayoutParams;

    const/4 v3, -0x1

    const/4 v4, -0x1

    const/16 v5, 0x7df

    const/16 v6, 0x538

    const/4 v7, -0x3

    invoke-direct/range {v2 .. v7}, Landroid/view/WindowManager$LayoutParams;-><init>(IIIII)V

    iget v3, v2, Landroid/view/WindowManager$LayoutParams;->privateFlags:I

    const v4, 0x100010

    or-int/2addr v3, v4

    iput v3, v2, Landroid/view/WindowManager$LayoutParams;->privateFlags:I

    const/4 v3, 0x1

    iput v3, v2, Landroid/view/WindowManager$LayoutParams;->layoutInDisplayCutoutMode:I

    new-instance v0, Landroid/widget/FrameLayout;

    iget-object v3, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->context:Landroid/content/Context;

    invoke-direct {v0, v3}, Landroid/widget/FrameLayout;-><init>(Landroid/content/Context;)V

    iput-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mBLFView:Landroid/widget/FrameLayout;

    const/16 v3, 0x200

    invoke-virtual {v0, v3}, Landroid/widget/FrameLayout;->setSystemUiVisibility(I)V

    iget-object v3, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->context:Landroid/content/Context;

    const-string v4, "window"

    invoke-virtual {v3, v4}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v3

    check-cast v3, Landroid/view/WindowManager;

    invoke-interface {v3, v0, v2}, Landroid/view/WindowManager;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V

    :cond_color
    iget-object v1, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->context:Landroid/content/Context;

    invoke-virtual {v1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v1

    const v2, 0x7e030095

    invoke-virtual {v1, v2}, Landroid/content/res/Resources;->getStringArray(I)[Ljava/lang/String;

    move-result-object v1

    array-length v2, v1

    add-int/lit8 v2, v2, -0x1

    if-le p2, v2, :cond_index

    move p2, v2

    :cond_index
    if-gez p2, :cond_parse

    const/4 p2, 0x0

    :cond_parse
    aget-object v1, v1, p2

    invoke-static {v1}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I

    move-result v1

    invoke-virtual {v0, v1}, Landroid/widget/FrameLayout;->setBackgroundColor(I)V

    return-void

    :cond_off
    iget-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mainThreadHandler$delegate:Lkotlin/Lazy;

    invoke-interface {v0}, Lkotlin/Lazy;->getValue()Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/os/Handler;

    new-instance v1, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$removeBlueLightFilterWindow$1;

    invoke-direct {v1, p0}, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$removeBlueLightFilterWindow$1;-><init>(Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;)V

    invoke-virtual {v0, v1}, Landroid/os/Handler;->post(Ljava/lang/Runnable;)Z

    return-void
.end method

.method public final setBlueLightFilterMode()V
    .locals 3

    iget-object v0, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->settingsHelper:Lcom/android/systemui/util/SettingsHelper;

    const-string v1, "blue_light_filter"

    invoke-virtual {v0, v1}, Lcom/android/systemui/util/SettingsHelper;->getBlueLightFilterMode(Ljava/lang/String;)I

    move-result v1

    const-string v2, "blue_light_filter_opacity"

    invoke-virtual {v0, v2}, Lcom/android/systemui/util/SettingsHelper;->getBlueLightFilterMode(Ljava/lang/String;)I

    move-result v2

    const/4 v0, 0x1

    if-eq v1, v0, :cond_0

    const/4 v0, 0x0

    :cond_0
    invoke-virtual {p0, v0, v2}, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->setBlueLightFilter(ZI)V

    return-void
.end method
