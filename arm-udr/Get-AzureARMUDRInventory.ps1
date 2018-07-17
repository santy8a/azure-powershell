<#
.Synopsis
   Obtiene un Inventario de las User Defined Routes que tenga una suscripción de Azure.

.DESCRIPTION
   - Este script ayuda a obtener una lista de UDR en formato PowerShell para que pueda ser guardado en un archivo csv.
   
   Cabeceras:
	==========

	- UDRName                --> Nombre de UDR
	- UDResourceGroupName    --> Nombre Resource Group UDR
	- UDRLocation            --> Ubicación UDR
	- Subnet                 --> Subnet a la que está atachada la UDR
    - RouteName              --> Nombre de ruta
	- RouteAddressPrefix     --> Dirección de la ruta
	- RouteNextHopType       --> Tipo de próximo salto. Posibles valores: Internet, None, VirtualAppliance, VirtualNetworkGateway, VnetLocal
	- RouteNextHopIpAddress  --> Dirección del próximo salto

.PARAMETER AzureUDRName 
   El nombre de la UDR que se quiere inventariar.  
   El parámetro no es obligatorio, si no se indica el script saca un inventario de todas las URDs existentes.

.EXAMPLE
   Sacar el inventario de todas las UDRs
   .\Get-AzureARMUDRInventory.ps1

.EXAMPLE
   Sacar el inventario de una UDR llamada UDR01
   .\Get-AzureARMUDRInventory.ps1 -$AzureUDRName UDR01

.INPUTS 
   Ninguno. 
 
.OUTPUTS 
   Un archivo .csv con el inventario de la o las UDRs.  

.NOTES
   AUTHOR: Santiago Ochoa 
   LASTEDIT: Julio 17, 2018 
#>

param( 
    [parameter(Mandatory=$false)] 
    [String] $AzureUDRName #= "UDR06" 
)

# Definiendo función que devuelve un listado de todas las rutas que tiene una UDR. Requiere que se indique por parámetro el array de Rutas.
function Get-UDRRouteList($AllAzureUDRRoutes)
{
	$AllUDRRouteList = @()
	$AllUDRRouteList += foreach($UDRRoute in $AllAzureUDRRoutes)
						{
							[pscustomobject]@{                                                     
												Name = $UDRRoute.Name
												AddressPrefix = $UDRRoute.AddressPrefix
												NextHopType = $UDRRoute.NextHopType
												NextHopIpAddress = $UDRRoute.NextHopIpAddress
                         					 }
						}
	return $AllUDRRouteList
}

# Definiendo función que devuelve un listado de UDRs en formato Objeto Powershell. Requiere que se le pase una o varias UDRs
function Get-UDRList($AllAzureUDRs)
{
	$AllUDRList = @()
	$AllUDRList += foreach($AzureUDR in $AllAzureUDRs)
							{
								$subnets = @()
								# Rutas
								if ($AzureUDR.Routes)
								{
									$subnets = foreach ($subnet in $AzureUDR.Subnets.Id)
												{
													$subnet.Split('/') | Select-Object -Last 1
												}
									foreach($routesUDR in (Get-UDRRouteList -AllAzureUDRRoutes $AzureUDR.Routes ))
									{									
										[pscustomobject]@{                                                     
															UDRName =               $AzureUDR.Name
															UDResourceGroupName =   $AzureUDR.ResourceGroupName
															UDRLocation =           $AzureUDR.Location
															UDRSubnet =             $subnets -join "/"
                            								RouteName =             $routesUDR.Name
															RouteAddressPrefix =    $routesUDR.AddressPrefix
															RouteNextHopType =      $routesUDR.NextHopType
															RouteNextHopIpAddress = $routesUDR.NextHopIpAddress
                         								}
									}
								}else
								{
									[pscustomobject]@{                                                     
															UDRName =               $AzureUDR.Name
															UDResourceGroupName =   $AzureUDR.ResourceGroupName
															UDRLocation =           $AzureUDR.Location
															Subnet =                $subnets -join "/"
                            								RouteName =             ""
															RouteAddressPrefix =    ""
															RouteNextHopType =      ""
															RouteNextHopIpAddress = ""
                         								}
								}
							}
	return $AllUDRList
}

# Para ser modificado.  Actualmente, inicia el nombre del archivo con la firma de fecha y hora. 
$OutputCSVPath = $PSScriptRoot + "\Inventory\"                      # Production Path
#$OutputCSVPath = "C:\Scripts\azure-powershell\arm-udr\Inventory\"  # Test Path
$OutputCSVFile = "{0:yyyyMMddHHmm}-AzureUDRList" -f (Get-Date)  
$outputCSVExt  = ".csv"

# Login Azure
"0- Login en Azure ARM..."
Login-AzureRmAccount

# Seleccionando Azure Subscription

$subscriptionId = (Get-AzureRmSubscription | Out-GridView -Title "Seleccione una Azure Subscription ..." -PassThru).SubscriptionId
Select-AzureRmSubscription -SubscriptionId $subscriptionId
#>

# Escanenado las UDRs 
"1- Escaneando todas las UDRs..."
$AllUDRs = Get-AzureRmRouteTable
"   Encontradas: " + $AllUDRs.Count

# Seleccionando UDR indicada por parámetro
"2- Escaneando todas las UDRs..."
if($AzureUDRName)
{
	"La UDR para el inventario es: $AzureUDRName" 
	$AllUDRs = $AllUDRs | Where-Object {$_.Name -eq "$AzureUDRName"}
}

# Obteniendo el listado de UDRs en formato PowerShell
"3- Obteniendo el listado de las UDRs..."
$AllUDRList = Get-UDRList -AllAzureUDRs $AllUDRs

# Define CSV Output Filename, use subscription name and ID as name can be duplicate
if($AzureUDRName)
{
	$OutputCSV = "$OutputCSVPath$OutputCSVFile - $AzureUDRName$outputCSVExt"
}else
{
	$OutputCSV = "$OutputCSVPath$OutputCSVFile - $subscriptionId$outputCSVExt"
}

# Imprimiendo el listado en la ruta
"La ruta del inventario es: $OutputCSV" 
$CSVResult = $AllUDRList | Export-Csv $OutputCSV -NoTypeInformation

Read-Host "Pulse cualquier tecla para salir"