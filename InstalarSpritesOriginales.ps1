# Instala una seleccion de los sprites extraidos del Age of War original.
# Fuente: https://github.com/apiotrowski255/age-of-war
# Selecciona PNG desde el ZIP en streaming, sin descomprimir los miles de archivos.
param(
    [string]$ArchivoZip = ""
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$directorio = Split-Path -Parent $MyInvocation.MyCommand.Path
$destino = Join-Path $directorio 'data\original'
New-Item -ItemType Directory -Path $destino -Force | Out-Null
$descarga = $false
try {
    if (-not $ArchivoZip) {
        $ArchivoZip = Join-Path $env:TEMP 'age-of-war-original-main.zip'
        if (-not (Test-Path $ArchivoZip) -or (Get-Item $ArchivoZip).Length -lt 1000000) {
            Write-Host 'Descargando recursos originales desde GitHub. Puede ocupar mas de 100 MB...' -ForegroundColor Cyan
            $url = 'https://codeload.github.com/apiotrowski255/age-of-war/zip/refs/heads/main'
            $cliente = New-Object System.Net.WebClient
            try { $cliente.DownloadFile($url, $ArchivoZip) }
            finally { $cliente.Dispose() }
            $descarga = $true
        } else {
            Write-Host "Usando ZIP ya descargado: $ArchivoZip" -ForegroundColor Cyan
        }
    }
    if (-not (Test-Path $ArchivoZip)) { throw "No se encuentra el ZIP: $ArchivoZip" }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivoZip)
    try {
        $grupos = @{}
        $simples = @{}
        $prefijo = 'age of war sprites/'
        foreach ($entry in $zip.Entries) {
            $ruta = $entry.FullName.Replace('\', '/')
            $pos = $ruta.IndexOf($prefijo, [System.StringComparison]::OrdinalIgnoreCase)
            if ($pos -lt 0) { continue }
            $rel = $ruta.Substring($pos + $prefijo.Length)
            if (-not $rel.EndsWith('.png', [System.StringComparison]::OrdinalIgnoreCase)) { continue }

            if ($rel -eq 'background.png' -or $rel -match '^bases/(cave|knight|future)/base/base\.png$') {
                if (-not $simples.ContainsKey($rel)) { $simples[$rel] = $entry }
                continue
            }
            if ($rel -match '^bases/(cave|knight|future)/turret_1/([^/]+\.png)$') {
                $era = $Matches[1]
                $nombre = $Matches[2]
                if ($nombre -match 'projectile') { $clave = "proyectil-$era" }
                elseif ($nombre -match 'attack') { $clave = "torreta-$era" }
                else { continue }
                if (-not $simples.ContainsKey($clave)) { $simples[$clave] = $entry }
                continue
            }
            if ($rel -match '^units/(cave|knight|future)/(melee|range|tank)/(walk|idle|attack|idle_attack)/[^/]+\.png$') {
                $key = "$($Matches[1])/$($Matches[2])/$($Matches[3])"
                if (-not $grupos.ContainsKey($key)) { $grupos[$key] = New-Object System.Collections.ArrayList }
                [void]$grupos[$key].Add($entry)
            }
        }

        $aCopiar = New-Object System.Collections.ArrayList
        foreach ($clave in $simples.Keys) { [void]$aCopiar.Add($simples[$clave]) }
        foreach ($clave in $grupos.Keys) {
            $lista = @($grupos[$clave] | Sort-Object -Property FullName)
            $n = [Math]::Min(10, $lista.Count)
            for ($i=0; $i -lt $n; $i++) {
                $indice = [Math]::Min($lista.Count - 1, [int][Math]::Floor(($i + 0.5) * $lista.Count / $n))
                [void]$aCopiar.Add($lista[$indice])
            }
        }

        $cantidad = 0
        foreach ($entry in $aCopiar) {
            $ruta = $entry.FullName.Replace('\','/')
            $pos = $ruta.IndexOf($prefijo, [System.StringComparison]::OrdinalIgnoreCase)
            if ($pos -lt 0) { continue }
            $rel = $ruta.Substring($pos + $prefijo.Length)
            $salida = Join-Path $destino ($rel.Replace('/', '\'))
            $carpetaSalida = Split-Path -Parent $salida
            if (-not (Test-Path $carpetaSalida)) { New-Item -ItemType Directory -Path $carpetaSalida -Force | Out-Null }
            $entradaStream = $entry.Open()
            $salidaStream = [System.IO.File]::Open($salida, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
            try { $entradaStream.CopyTo($salidaStream) }
            finally { $salidaStream.Dispose(); $entradaStream.Dispose() }
            $cantidad++
        }
        if (-not (Test-Path (Join-Path $destino 'background.png'))) { throw 'No se encontro background.png en el ZIP.' }
        if (-not (Test-Path (Join-Path $destino 'units\cave\melee\walk'))) { throw 'No se encontraron los sprites de unidades en el ZIP.' }
        Write-Host "INSTALACION COMPLETA: $cantidad imagenes en $destino" -ForegroundColor Green
        Write-Host 'Ya podes abrir AgeOfWar1v1.pde con Processing 4.' -ForegroundColor Green
    }
    finally { $zip.Dispose() }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Revisa que haya internet o pasa el ZIP descargado con: ' -ForegroundColor Yellow
    Write-Host 'powershell -File InstalarSpritesOriginales.ps1 -ArchivoZip C:\ruta\age-of-war-main.zip'
    exit 1
}
