#!/bin/bash

# ESTE SCRIPT ANALIZA Y DEPURA LOS DATOS DE LOS FICHEROS "REPORTES BOSS" EXTRAYENDO SOLO LOS DATOS NECESARIOS PARA 
# SU ANALISIS Y ARROJANDO TODOS LOS SECTORES JUNTOS PARA TENER ASI UN TOTAL COMPLETO

# Directorios script:
# bash /media/$USER/CA4D-951D/Scripts/"Shell Scripts"/CANTV/"analizador de REPORTES BOSS aba"/datosaba.sh

#-------------------------------------------------------------------------------------------------------------------#
#--------------------------------------------------- VARIABLES  ----------------------------------------------------#

origen=/home/"$USER"/Laboratorio-pruebas/"$USER"/Descargas  # Donde se encuentran los .zip a descomprimir
spacework=/home/"$USER"/poch/DatosABA                       # Donde serán exportado los ficheros listo

#-------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------- INICIO DE SCRIPT ------------------------------------------------#

# CREAR ESPACIO DE TRABAJO Y RENOMBRAR FICHEROS .ZIP PARA SUSTITUIR LOS ESPACIOS POR '_'
mkdir -p "$spacework"
cd "$origen"
for file in *.zip; do
    nuevoNombre=`echo $file | sed 's/ /_/g'`
    mv "$file" $nuevoNombre
done

# IR AL ESPACIO DE TRABAJO PARA DESCOMPRIMIR ALLÍ TODOS LOS .ZIP DE UNO EN UNO PARA TRABAJRA LOSFICHEROS POR PARTE 
cd "$spacework"
for zip in $(ls $origen/REPORTE*zip);do
    unzip "$zip"

    # CONVERTIR FICHEROS .XLSX A .CSV Y SE ALMACENA EL NOMBRE DE LOS FICHEROS FINALES COMO VARIABLE (AÑO/MES/DIA)
    libreoffice --headless --convert-to csv *.xlsx; rm *.xlsx #---se debe buscar otro paquete, porque libreoffice a veces falla
    clientes=$(ls | grep -i cliente)
    totales=$(ls | grep -i totales)
	sed -i '1d' "$clientes"
    sed -i '1d' "$totales"
    archivo=$(echo $clientes | awk -F"_" '{print $4}'| sed -e 's/.csv//g' | sed 's/FE//g'| awk 'BEGIN{FIELDWIDTHS="2 2 4"}{print $3,$2,$1}' | sed 's/ //g')
	
#    SE IMPRIME EL COID Y TOTAL DE PUERTOS A 'TotalPorts.coID' PARA AGREGARLOS A LOS FICHEROS
#    awk 'BEGIN {FS=","; OFS=";"} {print $2,$16}' $totales | sort >> TotalPorts.coID

    # ORDENAR EL FICHERO '$clientes' POR COID Y SE ELIMINAN LAS LINEAS SPAM QUE CONTENGAN INTERFACES DE PRUEBA (HASTA AHORA SE CONOCE 0 Y T200) 
	spam=$(awk 'BEGIN {FS=","; OFS=";"} {print $12,$11,$6,$14,$13,$16}' $clientes | sort)
    echo "$spam" > csv.tmp
    spam=$(echo "$spam"| cat -n | grep -we "T200" -e "0" | awk '{print $1}' | sort -r)
    for i in $spam; do sed -i "$i"d csv.tmp; done

    # IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
    echo "COID;ESTADO;REGIÓN/NODO;EQUIPO;CLIENTES;PLAN;VELOCIDAD POR PLAN" > T$archivo.csv

    # LIMPIAR SPAM DE REGION/NODOS Y SEPARAR EN DOS LOS FICHEROS PARA SUSTITUIR EL "." POR LA "," EN LOS CALCULOS SIN DAÑAR LA REGION/NODO 
    awk 'BEGIN {FS=";"; OFS=";"} {print $1,$2,$3";"}' csv.tmp | sed -e 's/ ABA NGN//g ; s/ ABA//g ; s/ 20011//g ; s/ 2008//g ; s/ 2007//g ; s/ 2009//g ; s/ 2010//g ; s/ 2011//g ; s/ 2012//g ; s/ 2013//g ; s/ 2014//g ; s/ 2015//g ; s/ 2016//g ; s/ 2017//g ; s/ 2018//g ; s/ 2019//g ; s/ 2020//g  ; s/ 2021//g  ; s/ 2022//g  ; s/ 2023//g  ; s/ 2024//g ; s/ 2025//g ; s/ 2026//g' > part1.tmp
    awk 'BEGIN {FS=";"; OFS=";"} { plan = $5/1024 } { print $1,$6,plan,(plan*$6) }' csv.tmp | tr -s "." "," > part2.tmp

    # IMPRIMIR VALORES DESPUES DE UNIR EL FICHERO ANTES SEPARADO
    paste part1.tmp part2.tmp | awk -F';' '{print $1,"",$2,$3,$5,$6,$7}' OFS=';' >> T$archivo.csv
    
    # CALCULO MATEMATICO PARA EL RESULTADO TOTAL Y PROMEDIO
    awk -F";" '{ plan = $5/1024 } { print $6,plan,(plan*$6) }' csv.tmp > bc.tmp
    varC=$(awk '{ clientes += $1 } END { print clientes }' bc.tmp)
    varV=$(awk '{ planClientes += $3 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)
    echo ";;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV" | tr -s "." "," >> T$archivo.csv

#------------------------------------ fichero con el contenido total CONCLUIDO -------------------------------------#
#-------------------------------------------------------------------------------------------------------------------#
#------------------------------------- fichero con el total por zona INICIADO --------------------------------------#

    # Almacena coid como array para agregar la palabra "limite" cada vez que cambie de valor en una linea nueva para
    # que pueda sustituirse por el total/promedio y añadir un salto de linea
    coID=$(awk -F";" '{print $1}' csv.tmp); coID=($coID)
    n=1
    for i in ${coID[@]}; do
        k=${coID[$n]}
        if [ "$i" == "$k" ];then
            echo "$i" >> $archivo.tmp
        else
            echo -e "$i\nlimite" >> $archivo.tmp
        fi
        n=$(($n+1))
    done    
    sed '1d' T$archivo.csv > a.tmp ; sed -i '$d' a.tmp
    limite=$(cat -n $archivo.tmp | grep limite | awk '{print $1}'); limite=($limite)
    
    # SE SELECCIONA EL PRIMER COID
    sed -n "1,$(($limite-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7}' > bc.tmp
    
    # CALCULOS MATEMATICOS POR COID
    varC=$(awk 'BEGIN { FS=";" ; OFS=";" } { clientes += $5 } END { print clientes }' bc.tmp)  
    varV=$(awk 'BEGIN { FS=";" ; OFS=";" } { planClientes += $7 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)
    
    # IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
    echo "COID;ESTADO;REGIÓN;EQUIPO;CLIENTES;PLAN;VELOCIDAD POR PLAN" > $archivo.csv
    sed -n "1,$(($limite-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7}' >> $archivo.csv
    echo -e ";;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV\n" | tr -s "." "," >> $archivo.csv

    j=1
    for (( i=0 ; i<=${#limite[*]} ; i++ )); do
        # SELECCIÓN DEL SIGUIENTE COID CORRESPONDIENTE
        sed -n "$((${limite[$i]}-$j+1)),$((${limite[$j]}-$j-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7}' > bc.tmp
        
        # CALCULOS MATEMATICOS POR EQUIPO
        varC=$(awk 'BEGIN { FS=";" ; OFS=";" } { clientes += $5 } END { print clientes }' bc.tmp)
        varV=$(awk 'BEGIN { FS=";" ; OFS=";" } { planClientes += $7 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)   
        
        #IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
        echo "COID;ESTADO;REGIÓN;EQUIPO;CLIENTES;PLAN;VELOCIDAD POR PLAN" >> $archivo.csv
        sed -n "$((${limite[$i]}-$j+1)),$((${limite[$j]}-$j-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7}' >> $archivo.csv
        echo -e ";;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV\n" | tr -s "." "," >> $archivo.csv       
        ((j++))
    done 2> /dev/null
    
    # ELIMINAR ULTIMAS 7 LINEAS SPAM
    i=0; while [ $i -lt 7 ]; do sed -i '$d' $archivo.csv; ((i++)); done
    

    # SE RENOMBRAN ARCHIVOS FINALES PARA ELIMINAR LOS TEMPORALES Y LOS .CSV (ASI NO SALDRAN PERJUDICADOS)
    mv $archivo.csv $archivo.csv.keiber ;  mv T$archivo.csv T$archivo.csv.keiber
    rm *.tmp *.csv
    mv $archivo.csv.keiber $archivo.csv;  mv T$archivo.csv.keiber T$archivo.csv

######################################## ALGORITMO DE ESTADO POR REGION/NODO ########################################

#     # test
#     awk -F';' '{print $2}' T$archivo.csv | sort | sed '1d' | uniq > reginodo.tmp
#     i=0; while IFS= read -r line; do reginodo[$i]=$line; ((i=$i+1)); done < reginodo.tmp
#     mkdir -p estado-region
#     n=1

#     # exporta las regiones y carpetas para ser revisado de uno en uno x.x
#     # y ver cual no necesita :D y cual necesita :c ser agregado a la base de dato
#     for i in "${reginodo[@]}"; do
#         echo "$n / 3748"
#         bash acronikey.sh --region "$i" | awk -F';' '{print $1}' | sort | uniq > estado-region/"$i.r"
#         bash acronikey.sh --nodo "$i" | awk -F';' '{print $1}' | sort | uniq > estado-region/"$i.n"
#         ((n=$n+1))
#     done
done