    .locals 1

    const-string p0, "statusbar"

    invoke-static {p0}, Landroid/os/ServiceManager;->checkService(Ljava/lang/String;)Landroid/os/IBinder;

    move-result-object p0

    invoke-static {p0}, Lcom/android/internal/statusbar/IStatusBarService$Stub;->asInterface(Landroid/os/IBinder;)Lcom/android/internal/statusbar/IStatusBarService;

    move-result-object p0

    if-eqz p0, :cond_skip

    :try_start_0
    invoke-interface {p0, p1, p2}, Lcom/android/internal/statusbar/IStatusBarService;->setBlueLightFilter(ZI)V
    :try_end_0
    .catch Landroid/os/RemoteException; {:try_start_0 .. :try_end_0} :cond_skip

    :cond_skip
    return-void
