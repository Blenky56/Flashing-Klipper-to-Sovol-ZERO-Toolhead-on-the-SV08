
#!/usr/bin/env bash

# This file has been modified by Blenky from Rappetor's update_klipper_mcus_sv08.sh so it works with the ZERO toolhead
#Replace each XXXXXXXX and YYYYYYY serial number with the one you find in your printer.cfg file (we only need the part after 'usb-Klipper_stm32f103xe_')
#HOSTSERIAL is found under [mcu]
#TOOLHEADSERIAL is found under [extra mcu]
# Generic command to find serials:

# I'm a string, so I look like: HOSTSERIAL='XXXXXXXX'
HOSTSERIAL='35FFD8054748303426712457-if00'  # Main Board MCU  Replace with your serial number

# I'm an array so I look like: TOOLHEADSERIAL=('YYYYYYY')
# For multiple serials/toolheads use (mind the space in between items!): TOOLHEADSERIALS=('YYYYYYY1' 'YYYYYYY2' 'YYYYYYY3')
TOOLHEADUUID=('27ed790d8665') # ZERO TH CAN serial number from Printer.cfg --> UUID: 27ed790d8665  STOCK: 61755fe321ac  Replace with your UUID numbers
FLASHTOOLHEAD=('61755fe321ac')

#COLORS
MAGENTA=$'\e[35m\n'
YELLOW=$'\e[33m\n'
RED=$'\e[31m\n'
CYAN=$'\e[36m\n'
NC=$'\e[0m\n'
NC0=$'\e'
NC1=$'\e[0m'


stop_klipper(){
	echo -e "${YELLOW}Stopping Klipper service.${NC}"
	sudo service klipper stop
}

start_klipper(){
	echo -e "${YELLOW}Starting Klipper service.${NC}"
	sudo service klipper start
}

update_klipper(){
	echo -e "${YELLOW}Updating Klipper service to host.${NC}"
	# uninstall eddy-ng
	cd ~/eddy-ng  # comment out if not using eddy-ng
	./install.sh --uninstall  # comment out if not using eddy-ng
	# update Klipper
	cd ~/klipper
	git pull
	# re-install eddy-ng
	cd ~/eddy-ng  # comment out if not using eddy-ng
	./install.sh  # comment out if not using eddy-ng
	cd
	read -p "${CYAN}HOST klipper Updated. Check for errors and press [Enter] to continue or Ctrl C to exit..${NC}"
}

	
flash_host(){
	cd "$HOME/klipper"
	echo -e "${YELLOW}Cleaning and building Klipper firmware for HOST MCU.${NC}"
	make clean KCONFIG_CONFIG=host.mcu
	read -p "${CYAN}Check on the following screen that the parameters are correct for the ${RED}HOST${CYAN}firmware. Press [Enter] to continue..${NC}"
	make menuconfig KCONFIG_CONFIG=host.mcu
	make KCONFIG_CONFIG=host.mcu -j4
	mv ~/klipper/out/klipper.bin ~/klipper/out/host_mcu_klipper.bin
	read -p "${CYAN}Host MCU firmware building complete. Press [Enter] to flash..${NC}"
	echo -e "${YELLOW}Flashing Klipper to HOST MCU.${NC}"
	cd ~/klipper/scripts/ && python3 -c 'import flash_usb as u; u.enter_bootloader("/dev/serial/by-id/usb-Klipper_stm32f103xe_'$HOSTSERIAL'")'
	sleep 3
	~/katapult/scripts/flashtool.py -f ~/klipper/host_mcu_klipper.bin -d /dev/serial/by-id/usb-katapult_stm32f103xe_$HOSTSERIAL
	read -p "${CYAN}HOST MCU flashed. Check for errors and press [Enter] to continue..${NC}"
}

flash_toolhead(){
	cd "$HOME/klipper"
	echo -e "${YELLOW}Cleaning and building Klipper firmware for TOOLHEAD MCU Set for STM32F103, 8MHz crystal, CAN bus on PB8/PB9.${NC}"
	make clean KCONFIG_CONFIG=extruder.mcu
	read -p "${CYAN}Check on the following screen that the parameters are correct for the ${RED}TOOLHEAD${CYAN}firmware. Press [Enter] to continue..${NC}"
	make menuconfig KCONFIG_CONFIG=extruder.mcu
	make KCONFIG_CONFIG=extruder.mcu -j4
	mv ~/klipper/out/klipper.bin ~/klipper/out/extruder_mcu_klipper.bin
	read -p "${CYAN}Extruder MCU firmware building complete. Press [Enter] to set bootmode..${NC}"
	echo "Get into bootloader ..."
	python3 ~/katapult/scripts/flash_can.py -i can0 -u $TOOLHEADUUID -r
	python3 ~/katapult/scripts/flashtool.py -i can0 -q
	read -p "${CYAN}Extruder UUID query complete. Press [Enter] to flash..${NC}"
	cd ~/katapult/scripts/ && python3 ~/katapult/scripts/flashtool.py -f ~/klipper/out/extruder_mcu_klipper.bin -u $FLASHTOOLHEAD
	sleep 5
	read -p "${CYAN}TOOLHEAD flashed. Check for errors and press [Enter] to continue..${NC}"
}

#SCRIPT EXECUTION
echo "Executing SV08 automatic mcu updater..."
stop_klipper

PS3='Please enter your choice: '
while true; do
	clear
	echo -e "${MAGENTA}AUTOMATIC MCU UPDATER for ZERO Toolhead Only...${NC1}"
	echo -e "Which device do you want to update (build & flash)?"
	options=("UPDATE KLIPPER TO HOST" "FLASH HOST MCU" "FLASH ZERO TOOLHEAD" "Quit") 
	COLUMNS=1
	select opt in "${options[@]}"
	do
		case $opt in
			"UPDATE KLIPPER TO HOST")
				update_klipper
				break
				;;
			"FLASH HOST MCU")
				flash_host
				break
				;;
			"FLASH ZERO TOOLHEAD")
				flash_toolhead
				break
				;;
			"Quit")
				echo "Quitting.."
				break 2
				;;
			*) echo "invalid option $REPLY";;
		esac
	done
done

start_klipper

cd "$HOME/klipper"