Import-Module ActiveDirectory
$usuarios = Import-Csv -Path "C:\Scripts\Usuarios.csv" -Delimiter ","

foreach ($user in $usuarios) {
    # Construir o caminho Distinguished Name (DN) exato
    $ouPath = "OU=$($user.OU),OU=LuminaCorp_Departamentos,DC=luminacorp,DC=local"
    $upn = "$($user.Login)@luminacorp.local"

    New-ADUser -Name "$($user.Nome) $($user.Sobrenome)" `
               -GivenName $user.Nome `
               -Surname $user.Sobrenome `
               -SamAccountName $user.Login `
               -UserPrincipalName $upn `
               -Department $user.Departamento `
               -Path $ouPath `
               -AccountPassword (ConvertTo-SecureString $user.Senha -AsPlainText -Force) `
               -Enabled $true `
               -PasswordNeverExpires $true

    Write-Host "Usuario creado: $($user.Login) asignado a la OU: $($user.OU)" -ForegroundColor Green
}
