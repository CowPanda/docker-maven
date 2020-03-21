$event_name = %1
$username = %2
$password = %3
$tags = @('3.6.3', '3.6', '3')
Get-ChildItem -Path windows\* -File -Include "Dockerfile.windows-*" | ForEach-Object {
    Push-Location
    $dockerfile = $_

    $windowsType = '-windowsservercore'
    $windowsDockerTag = 'ltsc2019'
    $windowsReleaseId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ReleaseID | Select-Object ReleaseID).ReleaseID

    if($dockerfile.Name.Contains('nanoserver')) {
    $windowsType = ''
    $windowsDockerTag = $windowsReleaseId
    }

    if($dockerfile.Name.Contains('jdk-')) {
    $windowsDockerTag = $windowsReleaseId
    }

    # run tests
    Push-Location
    $env:TAG=$dockerfile.Name.Replace('Dockerfile.windows-', '')
    $env:WINDOWS_DOCKER_TAG=$windowsDockerTag
    Invoke-Pester -Path tests
    Remove-Item env:\TAG
    Remove-Item env:\WINDOWS_DOCKER_TAG
    Pop-Location

    $tags | ForEach-Object {
    Push-Location windows
    $tag = ('csanchez/maven:{0}-{1}{2}-{3}' -f $_,$dockerfile.Name.Replace('Dockerfile.windows-', ''),$windowsType,$windowsDockerTag)
    docker build -f $dockerfile --tag $tag --build-arg WINDOWS_DOCKER_TAG=${windowsDockerTag} .

    if($event_name -eq 'push') {
        # docker login with cause a warning which will cause this to fail unless we SilentlyContinue
        $ErrorActionPreference = 'SilentlyContinue'
        $password | & docker login --username $username --password-stdin
        $ErrorActionPreference = 'Stop'
        Write-Host "Pushing $tag"
        & docker push $tag
    }
    Pop-Location
    }
    Pop-Location
}
