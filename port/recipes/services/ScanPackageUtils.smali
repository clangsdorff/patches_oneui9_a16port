.field public static sCustomPlatformSignatures:[Landroid/content/pm/Signature;

.method public static getCustomPlatformSignatures()[Landroid/content/pm/Signature;
    .locals 3

    sget-object v0, Lcom/android/server/pm/ScanPackageUtils;->sCustomPlatformSignatures:[Landroid/content/pm/Signature;

    if-nez v0, :cond_0

    const/4 v0, 0x1

    new-array v0, v0, [Landroid/content/pm/Signature;

    new-instance v1, Landroid/content/pm/Signature;

    const-string v2, "PUT SIGNATURE HERE"

    invoke-direct {v1, v2}, Landroid/content/pm/Signature;-><init>(Ljava/lang/String;)V

    const/4 v2, 0x0

    aput-object v1, v0, v2

    sput-object v0, Lcom/android/server/pm/ScanPackageUtils;->sCustomPlatformSignatures:[Landroid/content/pm/Signature;

    :cond_0
    return-object v0
.end method

.method public static applyCustomSignatures(Lcom/android/server/pm/InstallPackageHelper;Lcom/android/internal/pm/parsing/pkg/ParsedPackage;)V
    .locals 3

    iget-object v0, p0, Lcom/android/server/pm/InstallPackageHelper;->mPm:Lcom/android/server/pm/PackageManagerService;

    iget-object v0, v0, Lcom/android/server/pm/PackageManagerService;->mPlatformPackage:Lcom/android/server/pm/pkg/AndroidPackage;

    invoke-static {}, Lcom/android/server/pm/ScanPackageUtils;->getCustomPlatformSignatures()[Landroid/content/pm/Signature;

    move-result-object v1

    invoke-interface {p1}, Lcom/android/internal/pm/parsing/pkg/ParsedPackage;->getSigningDetails()Landroid/content/pm/SigningDetails;

    move-result-object v2

    invoke-virtual {v2}, Landroid/content/pm/SigningDetails;->getSignatures()[Landroid/content/pm/Signature;

    move-result-object v2

    invoke-static {p1, v0, v1, v2}, Lcom/android/server/pm/ScanPackageUtils;->setCustomSignatures(Lcom/android/internal/pm/parsing/pkg/ParsedPackage;Lcom/android/server/pm/pkg/AndroidPackage;[Landroid/content/pm/Signature;[Landroid/content/pm/Signature;)V

    return-void
.end method
