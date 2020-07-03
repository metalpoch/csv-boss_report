#!/bin/bash

# ESTE SCRIPT ANALIZA Y DEPURA LOS DATOS DE LOS FICHEROS "REPORTES BOSS" EXTRAYENDO SOLO LOS DATOS NECESARIOS PARA 
# SU ANALISIS Y ARROJANDO TODOS LOS SECTORES JUNTOS PARA TENER ASI UN TOTAL COMPLETO

# Directorios script:
# bash "/media/$USER/CA4D-951D/Scripts/Shell Scripts/CANTV/Finalizados/datosaba/datosaba.sh"
#-------------------------------------------------------------------------------------------------------------------#
#--------------------------------------------------- VARIABLES  ----------------------------------------------------#
#database="/media/$USER/CA4D-951D/Scripts/Shell Scripts/CANTV/Finalizados/datosaba/database.kei"
database="/media/$USER/CA4D-951D/Scripts/Shell Scripts/CANTV/Finalizados/datosaba/EdoCoid.kei"
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
	
    # SE IMPRIME coid,region,equipo,DSLAMIP,AGREGADOR(LOCATION+NRPNAME),PUERTOS EN FIChERO TEMPORAL
    awk 'BEGIN {FS=","; OFS=";"} {print $2,$4,$3,$5,$12"-"$13,$16}' $totales | sort > tvar.tmp

    # ORDENAR EL FICHERO '$clientes' POR COID Y SE ELIMINAN LAS LINEAS SPAM QUE CONTENGAN INTERFACES DE PRUEBA (HASTA AHORA SE CONOCE 0 Y T200) 
	spam=$(awk 'BEGIN {FS=","; OFS=";"} {print $12,$11,$6,$14,$13,$16}' $clientes | sort)
    echo "$spam" > csv.tmp
    spam=$(echo "$spam"| cat -n | grep -we "T200" -e "0" | awk '{print $1}' | sort -r)
    for i in $spam; do sed -i "$i"d csv.tmp; done

    # IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
    echo "COID;ESTADO;REGIÓN/NODO;EQUIPO;DSLAMIP;AGREGADOR;CLIENTES;PLAN;VELOCIDAD POR PLAN;ESTATUS;PUERTOS POR COID" > T$archivo.csv

    # LIMPIAR SPAM DE REGION/NODOS Y SEPARAR EN DOS LOS FICHEROS PARA SUSTITUIR EL "." POR LA "," EN LOS CALCULOS SIN DAÑAR LA REGION/NODO 
    awk 'BEGIN {FS=";"; OFS=";"} {print $1,$2}' csv.tmp > part1.tmp
    awk 'BEGIN {FS=";"; OFS=";"} { plan = $5/1024 } { print $6,plan,(plan*$6),$4 }' csv.tmp | tr -s "." "," > part2.tmp

    # IMPRIMIR VALORES DESPUES DE UNIR EL FICHERO ANTES SEPARADO
    #paste part1.tmp part2.tmp | awk -F';' '{print $1,$2,$3,$5,$6,$7}' OFS=';' >> T$archivo.csv.tmp
    paste -d ";" part1.tmp part2.tmp > T$archivo.csv.tmp
    
    # CALCULO MATEMATICO PARA EL RESULTADO TOTAL Y PROMEDIO
    awk -F";" '{ plan = $5/1024 } { print $6,plan,(plan*$6) }' csv.tmp > bc.tmp
    varC=$(awk '{ clientes += $1 } END { print clientes }' bc.tmp)
    varV=$(awk '{ planClientes += $3 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)
    totalF=$(echo ";;;;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV" | tr -s "." ",")



    # se exporta las regiones existente en fichero temporal y se crea un array con cada linea de este fichero region
    # para buscar coincidencia linea a linea y exportar la que tengan resultado positivo, luego se eliminan las lineas repetidas
    awk 'BEGIN {FS=";"; OFS=";"} {print $2}' T$archivo.csv.tmp | sort | uniq > region.tmp
    i=0; while IFS= read -r line; do region[$i]=$line; ((i=$i+1)); done < region.tmp
    max=$i

    for ((i=0;i<max;i++));do
        resultado=$(grep -w "${region[$i]}" tvar.tmp)
        if [ -n "$resultado" ]; then
            echo "$resultado" >> temp.tmp 
        fi
    done
    awk '!array_temp[$0]++' temp.tmp > part3.tmp   #eliminar lineas repetidas 'no consecutivas' con awk

    #Se unen los ficheros con awk para que las uniones esten correspondida por los coid y region
    # FUNCIONA!!! no se por que pero funciona esta unio... nota: deno estudiar awk
    awk 'BEGIN {FS=";"; OFS=";"} NR==FNR{a[$1,$2]=$0; next}{$7=a[$1,$2];print}' part3.tmp T$archivo.csv.tmp > temp.tmp 

    # Se ordena la salida
    awk 'BEGIN {FS=";"; OFS=";"} {print $1,$2,$9,$10,$11,$3,$4,$5,$6,$12}' temp.tmp > test.tmp
    
    # Edo por coid
    i=0; while IFS= read -r line; do estado[$i]=$line; ((i=$i+1)); done < test.tmp
    max=$i
    for ((i=0;i<max;i++));do
        coid=$(echo ${estado[$i]} | awk -F';' '{print $1}')
        resultado=$(grep -w "$coid" "$database" | awk -F';' '{print $1}')
        if [ -n "$resultado" ]; then
            echo "$coid;$resultado" >> edotmp.csv
        else
            echo "$coid;No entontrado en la base de dato" >> edotmp.csv
            echo "$coid;No entontrado en la base de dato" >> "$archivo-error.log"
        fi
    done
    paste -d";" edotmp.csv test.tmp | awk 'BEGIN {FS=";"; OFS=";"} {print $1,$2,$4,$5,$6,$7,$8,$9,$10,$11,$12}' >> T$archivo.csv

    # Total cliente y Velocidad promedio
    echo $totalF >> T$archivo.csv

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
    sed -n "1,$(($limite-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' > bc.tmp
    
    # CALCULOS MATEMATICOS POR COID
    varC=$(awk 'BEGIN { FS=";" ; OFS=";" } { clientes += $7 } END { print clientes }' bc.tmp)  
    varV=$(awk 'BEGIN { FS=";" ; OFS=";" } { planClientes += $9 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)
    
    # IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
    echo "COID;ESTADO;REGIÓN/NODO;EQUIPO;DSLAMIP;AGREGADOR;CLIENTES;PLAN;VELOCIDAD POR PLAN;ESTATUS;PUERTOS POR COID" > $archivo.csv
    sed -n "1,$(($limite-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' >> $archivo.csv
    echo -e ";;;;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV\n" | tr -s "." "," >> $archivo.csv

    j=1
    for (( i=0 ; i<=${#limite[*]} ; i++ )); do
        # SELECCIÓN DEL SIGUIENTE COID CORRESPONDIENTE
        sed -n "$((${limite[$i]}-$j+1)),$((${limite[$j]}-$j-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' > bc.tmp
        
        # CALCULOS MATEMATICOS POR EQUIPO
        varC=$(awk 'BEGIN { FS=";" ; OFS=";" } { clientes += $5 } END { print clientes }' bc.tmp)
        varV=$(awk 'BEGIN { FS=";" ; OFS=";" } { planClientes += $7 } END { printf "%.2f \n", planClientes/NR }' bc.tmp)   
        
        #IMPRIMIR CABECERA Y LAS COLUMNAS CON SUS RESPECTIVOS RESULTADO DE CALCULOS AL FINAL
        echo "COID;ESTADO;REGIÓN/NODO;EQUIPO;DSLAMIP;AGREGADOR;CLIENTES;PLAN;VELOCIDAD POR PLAN;ESTATUS;PUERTOS POR COID" >> $archivo.csv
        sed -n "$((${limite[$i]}-$j+1)),$((${limite[$j]}-$j-1))"p a.tmp | awk 'BEGIN { FS=";" ; OFS=";" } { print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' >> $archivo.csv
        echo -e ";;;;;CLIENTES TOTALES:;$varC;VELOCIDAD PROMEDIO:;$varV\n" | tr -s "." "," >> $archivo.csv
        ((j++))
    done 2> /dev/null
    
    # ELIMINAR ULTIMAS 7 LINEAS SPAM
    #i=0; while [ $i -lt 7 ]; do sed -i '$d' $archivo.csv; ((i++)); done
    

    # SE RENOMBRAN ARCHIVOS FINALES PARA ELIMINAR LOS TEMPORALES Y LOS .CSV (ASI NO SALDRAN PERJUDICADOS)
    mv $archivo.csv $archivo.csv.keiber ;  mv T$archivo.csv T$archivo.csv.keiber
    rm *.tmp *.csv
    mv $archivo.csv.keiber $archivo.csv;  mv T$archivo.csv.keiber T$archivo.csv

done


#    3808 Yucat<DF>n 1 ABA
#    3809 Yucat<DF>n 2 ABA


# transformas de columnas a filas la base de dato de estadocoid:
# edo=$(ls edo/);time for i in $edo; do cat edo/$i | tr -s "\n" " " >> EdoCoid.kei; echo "" >> EdoCoid.kei;done