    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->context:Landroid/content/Context;

    new-instance p1, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile$$ExternalSyntheticLambda0;

    invoke-direct {p1}, Ljava/lang/Object;-><init>()V

    invoke-static {p1}, Lkotlin/LazyKt__LazyJVMKt;->lazy(Lkotlin/jvm/functions/Function0;)Lkotlin/Lazy;

    move-result-object p1

    iput-object p1, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->mainThreadHandler$delegate:Lkotlin/Lazy;

    iput-object p2, p0, Lcom/android/systemui/qp/qs/tiles/SBlueLightFilterSWTile;->settingsHelper:Lcom/android/systemui/util/SettingsHelper;

    return-void
