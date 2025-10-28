<#
.SYNOPSIS
  Настраивает SSH-подключение к GitHub для текущего Git-репозитория.

.DESCRIPTION
  Скрипт выполняет автоматическую проверку и настройку SSH-доступа:
    1. Проверяет, установлен ли git и ssh-agent.
    2. Проверяет, находимся ли мы в git-репозитории.
    3. Меняет origin-URL с HTTPS на SSH (git@github.com:USERNAME/REPO.git).
    4. Проверяет активность ssh-agent и наличие ключей.
    5. Тестирует подключение к GitHub.
    6. Выполняет `git fetch origin` и показывает статус.

.PARAMETER Username
  Твой GitHub username (например, LSV28).

.PARAMETER Repo
  Название репозитория (например, my_api_project).

.EXAMPLE
  PS C:\Projects\my_api_project> .\fix_git_ssh.ps1 -Username "LSV28" -Repo "my_api_project"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$Repo
)

Write-Host "=== Проверка git-репозитория ===" -ForegroundColor Cyan
if (-not (Test-Path ".git")) {
    Write-Host "❌ Текущая директория не является Git-репозиторием." -ForegroundColor Red
    Write-Host "Перейди в папку проекта, где есть .git" -ForegroundColor Yellow
    exit 1
}

# Проверка наличия git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Git не найден. Установи Git и добавь его в PATH." -ForegroundColor Red
    exit 1
}

# Проверка ssh-agent
Write-Host "`n=== Проверка ssh-agent ===" -ForegroundColor Cyan
$service = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($null -eq $service) {
    Write-Host "❌ Служба ssh-agent не найдена. Установи OpenSSH Client через 'Optional Features' Windows." -ForegroundColor Red
    exit 1
}
if ($service.Status -ne "Running") {
    Write-Host "▶ Запуск ssh-agent..." -ForegroundColor Yellow
    Start-Service ssh-agent
    Set-Service -Name ssh-agent -StartupType Automatic
}
Write-Host "✅ ssh-agent работает" -ForegroundColor Green

# Проверка наличия ключей
Write-Host "`n=== Проверка SSH-ключей ===" -ForegroundColor Cyan
$keys = & ssh-add -l 2>$null
if ($LASTEXITCODE -ne 0 -or $keys -match "The agent has no identities") {
    Write-Host "⚠️  Ключи не добавлены. Добавляем ~/.ssh/id_ed25519..." -ForegroundColor Yellow
    $keyPath = "$env:USERPROFILE\.ssh\id_ed25519"
    if (Test-Path $keyPath) {
        ssh-add $keyPath
        Write-Host "✅ Ключ добавлен в агент." -ForegroundColor Green
    } else {
        Write-Host "❌ Ключ не найден: $keyPath" -ForegroundColor Red
        Write-Host "Создай ключ: ssh-keygen -t ed25519 -C 'your_email@example.com'" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✅ Ключ уже загружен в ssh-agent." -ForegroundColor Green
}

# Настройка origin
Write-Host "`n=== Настройка Git origin на SSH ===" -ForegroundColor Cyan
$sshUrl = "git@github.com:$Username/$Repo.git"
git remote set-url origin $sshUrl
Write-Host "✅ Новый origin установлен: $sshUrl" -ForegroundColor Green

# Проверка подключения
Write-Host "`n=== Проверка подключения к GitHub ===" -ForegroundColor Cyan
ssh -T git@github.com
if ($LASTEXITCODE -ne 1 -and $LASTEXITCODE -ne 0) {
    Write-Host "❌ Ошибка подключения по SSH." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Подключение по SSH работает!" -ForegroundColor Green
}

# Финальная проверка
Write-Host "`n=== Финальные команды ===" -ForegroundColor Cyan
git fetch origin
git status

Write-Host "`n🎉 Готово! Репозиторий подключен по SSH и готов к работе." -ForegroundColor Green
