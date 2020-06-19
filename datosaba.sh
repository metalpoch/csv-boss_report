#!/bin/bash

# ESTE SCRIPT ANALIZA Y DEPURA LOS DATOS DE LOS FICHEROS "REPORTES BOSS" EXTRAYENDO SOLO LOS DATOS NECESARIOS PARA SU ANALISIS
# Directorios script:
# bash /media/$USER/CA4D-951D/Scripts/"Shell Scripts"/CANTV/"analizador de REPORTES BOSS aba"/datosaba.sh

#-----------------------------------------------------------------------------------#
#----------------------------------- VARIABLES  ------------------------------------#

origen=/home/"$USER"/Laboratorio-pruebas/"$USER"/Descargas
spacework=/home/"$USER"/Laboratorio-pruebas/"$USER"/poch/ConsumoABAcliente
# ruta script terminado: spacework=/home/"$USER"/poch/ClienteABA

#-----------------------------------------------------------------------------------#
#--------------------------------- INICIO DE SCRIPT --------------------------------#

mkdir -p "$spacework"/coID/{clientes,totales}                                       # Se crea el espacio de trabajo
cd "$origen"                                                                        # Ir al espacio de origen (donde estan los .zip)
for file in *.zip; do                                                               # Se cambia el nombre de los ficheros .zip para quitarle
    nuevoNombre=`echo $file | sed 's/ /_/g'`                                        # los espacios (me estaban jodiendo el script ese hp nombre)
    mv "$file" $nuevoNombre
done

cd "$spacework"                                                                     # Ir al espacio de trabajo del script

for zip in $(ls $origen/REPORTE*zip);do                                             # Descomprimir .zip de uno en uno para trabajar por parte
    unzip "$zip"                                                                    # Descomprimir del .zip al espacio de trabajo
    libreoffice --headless --convert-to csv *.xlsx; rm *.xlsx                       # Covertir de .xlsx a .csv
    clientes=$(ls | grep -i cliente)                                                # Tomar los ficheros Clientes* como variable
    totales=$(ls | grep -i totales)                                                 # Tomar los ficheros Totales* como variable
	sed -i '1d' "$clientes"                                                         # Se elimina la primera linea (membrete) para ordenar por coID
    sed -i '1d' "$totales"                                                          # y se extraen las columnas a un archivo temporal con awk
   

    # crear el fichero FINAL .csv con su fecha como nombre, con el siguiente formato: año/mes/dia
    archivo=$(echo $clientes | awk -F"_" '{print $4}'| sed -e 's/.csv//g' | sed 's/FE//g'| awk 'BEGIN{FIELDWIDTHS="2 2 4"}{print $3,$2,$1}' | sed 's/ //g')
	echo "COID;ESTADO;REGIÓN;EQUIPO;CLIENTES;PLAN;VELOCIDAD" > $archivo.csv

    awk 'BEGIN {FS=","; OFS=";"} {print $2,$16}' $totales | sort >> $totales.tmp
    mv $totales.tmp $totales

    # variable con el contenido del .csv con spam
	csvSpam=$(awk 'BEGIN {FS=","; OFS=";"} {print $12,$11,$6,$14,$13,$16}' $clientes | sort)
    echo "$csvSpam" > csv.tmp
    # Borrar spam (lineas con interfaces de pruebas, hasta ahora conocido los coID: 0 y T200)
    spam=$(echo "$csvSpam"| cat -n | grep -we "T200" -e "0" | awk '{print $1}' | sort -r)
    
    # Se procede a borrar las lineas "spam"
    for i in $spam;do
        sed -i "$i"d csv.tmp
    done

    # # COID, ESTADO, REGIÓN, EQUIPO, PLAN, CLIENTES, PLANxCLIENTE 
    # awk 'BEGIN {FS=";"; OFS=";"} { print $1,"",$2,$3,$6,($5/1024),($5*$6/1024) }' csv.tmp >> $archivo.tmp
    #
    # # fila: TOTAL                   # LOS VALORES CON DECIMALES NO SON TOMADOS SON TOMADO COMO CADENA DE TEXTO, EL RESULTADO FINAL NO ES VALIDO
    # total=$(awk '
    #             {FS=";"; OFS=";"}
    #             { c += $5 ; p += $6 ; cp += $5*$6 }
    #             END { printf c";" ; printf p";" ; printf "%.2f \n", cp }' $archivo.tmp)

    # # Imprimir ultima fila
    # echo ";;;TOTAL:;$total" >> $archivo.tmp
done


######## TEST###############


    # COID, ESTADO, REGIÓN, EQUIPO, PLAN, CLIENTES, PLANxCLIENTE 
    awk 'BEGIN {FS=";"; OFS=";"} { print $1,"",$2,$3,$6,$5,($5*$6) }' csv.tmp >> $archivo.csv

    # TERMINAR DE HACER LOS CALCULOS MATEMATICOS CON BC Y ARROJARLO EN LA ULTIMA FILA DE CSV 
    awk -F";" '{ print $6,$5,($5*$6) }' csv.tmp > tt.tmp            
    varcp=$(awk '{ clientes += $1 ; plan += $2 ; planClientes += $3 } END {print clientes";", plan}' tt.tmp)
    varTCP=$(awk '{ planClientes += $3 } END { printf "%.2f \n", planClientes }' tt.tmp)

    # Imprimir ultima fila
    echo ";;;TOTAL:;$varcp;$varTCP" >> $archivo.csv
