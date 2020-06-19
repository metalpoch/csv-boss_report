#!/bin/bash

# ESTE SCRIPT ANALIZA Y DEPURA LOS DATOS DE LOS FICHEROS "REPORTES BOSS" EXTRAYENDO SOLO LOS DATOS NECESARIOS PARA SU ANALISIS
# Y ARROJANDO TODOS LOS SECTORES JUNTOS PARA TENER ASI UN TOTAL COMPLETO

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
	echo "COID;ESTADO;REGIÓN;EQUIPO;CLIENTES;PLAN;VELOCIDAD POR PLAN" > T$archivo.csv

    awk 'BEGIN {FS=","; OFS=";"} {print $2,$16}' $totales | sort >> $totales.tmp
    mv $totales.tmp $totales

    # variable con el contenido del .csv con spam
	spam=$(awk 'BEGIN {FS=","; OFS=";"} {print $12,$11,$6,$14,$13,$16}' $clientes | sort)
    echo "$spam" > csv.tmp
    # Borrar spam (lineas con interfaces de pruebas, hasta ahora conocido los coID: 0 y T200)
    spam=$(echo "$spam"| cat -n | grep -we "T200" -e "0" | awk '{print $1}' | sort -r)
    
    # Se procede a borrar las lineas "spam"
    for i in $spam;do
        sed -i "$i"d csv.tmp
    done

    # COID, ESTADO, REGIÓN, EQUIPO, PLAN, CLIENTES, VELOCIDAD POR PLAN 
    awk 'BEGIN {FS=";"; OFS=";"} { plan = $5/1024 } { print $1,"",$2,$3,$6,plan,(plan*$6) }' csv.tmp | tr -s "." "," >> T$archivo.csv
    awk -F";" '{ plan = $5/1024 } { print $6,plan,(plan*$6) }' csv.tmp > tt.tmp               # Total de clientes, #planes y promedio de velocidad           
    varC=$(awk '{ clientes += $1 } END { print clientes }' tt.tmp)
    #varP=$(awk '{ plan += $2 } END { printf "%.2f \n", plan }' tt.tmp)
    varTCP=$(awk '{ planClientes += $3 } END { printf "%.2f \n", planClientes/NR }' tt.tmp)

    # Imprimir ultima fila
    echo ";;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varTCP" | tr -s "." "," >> T$archivo.csv


#########################################################################################################################################
####################################################  SACAR TOTAL DE VALORES PUNTUALES POR COID #########################################



done