#! /bin/sh

# Входные параметры
wine_pkg=
libwine_pkg=
wine_etersoft_pkg=
hasp_pkg=
font_pkg=
license=
serial=
type_product=
owner=
is_test=

error()
{
	echo $1
	rm -r -f $TMP_DIR
	exit 1
}

# Определяемые внутри скрипта параметры
WINE_VERSION="1.0.7"
DATE_RELASE="1 may 2007"
TMP_DIR="./WineEtersoft"
#SRC_FILE="/var/ftp/pub/Etersoft/WINE@Etersoft-1.0.7/sources/tarball/wine-etersoft-public-20070418.tar.bz2"
SRC_FILE="/home/andrey/tmp/wine-etersoft-public-20070418.tar.bz2"

LINUX_DISTRIB=`distr_vendor -d` || error "Can not run distr_vendor"
if [ $LINUX_DISTRIB == "Generic" ]; then
	error "Can not chack Linux distrib"
fi

LINUX_VERSION=`distr_vendor -v` || error "Can not run distr_vendor"
if [ $LINUX_VERSION == "Generic" ]; then
	error "Can not chack Linux version"
fi


# Вычитываем параметры командной строки
error_param()
{
	echo 'Use next params (all must be used):'
	echo --wine wine_package
	echo --libwine libwine_package
	echo --wine_etersoft wine_etersoft_package
	echo --hasp hasp_package
	echo --font font_package
	echo --license license_file
	echo For packages you can use param not_used
	echo --serial serial_number
	echo '--type_product type_product (Local, Network or SQL)'
	echo '--owner "name and famale of owner"'
	echo --is_test True or False
	exit 1
}

get_param()
{
	case $1 in
	--wine)
		if [ $2 == "not_used" ] || [ -f $2 ]; then 
			wine_pkg=$2 
		else 
			echo 'Error value of --wine ' $2
			error_param
		fi
		;;
	--libwine)
		if [ $2 == "not_used" ] || [ -f $2 ]; then 
			libwine_pkg=$2 
		else 
			echo 'Error value of --libwine ' $2
			error_param
		fi
		;;
	--wine_etersoft)
		if [ $2 == "not_used" ] || [ -f $2 ]; then 
			wine_etersoft_pkg=$2 
		else 
			echo 'Error value of --wine_etersoft ' $2
			error_param
		fi
		;;
	--hasp)
		if [ $2 == "not_used" ] || [ -f $2 ]; then 
			hasp_pkg=$2 
		else 
			echo 'Error value of --hasp ' $2
			error_param
		fi
		;;
	--font) 
		if [ $2 == "not_used" ] || [ -f $2 ]; then 
			font_pkg=$2 
		else 
			echo 'Error value of --font ' $2
			error_param
		fi
		;;
	--license)
		if [ -f $2 ]; then 
			license_file=$2 
		else 
			echo 'Error value of --license ' $2
			error_param
		fi
		;;

	--serial) serial=$2 ;;
	--type_product) 
		if [ "$2" == "Local" ] || [ "$2" == "Network" ] || [ "$2" == "SQL" ]; then
			type_product=$2
		else
			echo 'Error value of --type_product ' $2
			error_param
		fi
		;;
					
	--owner) 
		owner=$2
		;;
	--is_test) 
		if [ "$2" == "True" ] || [ "$2" == "False" ]; then
			is_test=$2
		else
			echo 'Error value of --is_test ' $2
			error_param
		fi
		;;
	*) echo "Unknown parameter " $1
		error_param 
		;;
	esac
}

while [ -n "$1" ]
do
	
	get_param $1 "$2"
	shift
	shift
done

# Создаем временную папку 
rm -r -f $TMP_DIR
mkdir $TMP_DIR || error "Can not create dir:" $TMP_DIR
# Копируем пакеты wine
mkdir $TMP_DIR/PKG || error "Can not create dir:" $TMP_DIR/PKG
if [ "$wine_pkg" == "" ]; then
	echo "Error: --wine not found"
	error_param
fi
if [ "$wine_pkg" != "not_used" ]; then
	cp $wine_pkg $TMP_DIR/PKG
fi

if [ "$libwine_pkg" == "" ]; then
	echo "Error: --libwine not found"
	error_param
fi
if [ "$libwine_pkg" != "not_used" ]; then
	cp $libwine_pkg $TMP_DIR/PKG
fi

if [ "$wine_etersoft_pkg" == "" ]; then
	echo "Error: --wine_etersoft not found"
	error_param
fi
if [ "$wine_etersoft_pkg" != "not_used" ]; then
	cp $wine_etersoft_pkg $TMP_DIR/PKG
fi

if [ "$hasp_pkg" == "" ]; then
	echo "Error: --hasp not found"
	error_param
fi
if [ "$hasp_pkg" != "not_used" ]; then
	cp $hasp_pkg $TMP_DIR/PKG
fi

if [ "$font_pkg" == "" ]; then
	echo "Error: --font not found"
	error_param
fi
if [ "$font_pkg" != "not_used" ]; then
	cp $font_pkg $TMP_DIR/PKG
fi

# Копируем файл лицензии
if [ "$license_file" != "" ]; then
	html2text -nobs -width 70 $license_file > $TMP_DIR/PKG/license.txt
fi

# Создаем hash файл
cd $TMP_DIR/PKG/
md5sum * > MD5SUM
cd ../..

# Создаем info файл
echo linux_distrib = $LINUX_DISTRIB > $TMP_DIR/PKG/wine_etersoft.info
echo linux_version = $LINUX_VERSION >> $TMP_DIR/PKG/wine_etersoft.info
echo wine_name = $type_product >> $TMP_DIR/PKG/wine_etersoft.info
echo wine_version = $WINE_VERSION >> $TMP_DIR/PKG/wine_etersoft.info
echo WINE_pkg = `basename $wine_pkg` >> $TMP_DIR/PKG/wine_etersoft.info
echo libwine_pkg = `basename $libwine_pkg` >> $TMP_DIR/PKG/wine_etersoft.info
echo wine-etersoft_pkg = `basename $wine_etersoft_pkg` >> $TMP_DIR/PKG/wine_etersoft.info
echo hash_file = MD5SUM >> $TMP_DIR/PKG/wine_etersoft.info
echo hasp_pkg = `basename $hasp_pkg` >> $TMP_DIR/PKG/wine_etersoft.info
echo font_pkg = `basename $font_pkg` >> $TMP_DIR/PKG/wine_etersoft.info
echo hash_file = license.txt >> $TMP_DIR/PKG/wine_etersoft.info

# Копируем файлы графики
mkdir $TMP_DIR/wineGUI || error "Can not create dir:" $TMP_DIR/wineGUI
mkdir $TMP_DIR/wineGUI/wineGUI_module || error "Can not create dir:" $TMP_DIR/wineGUI/wineGUI_module
mkdir $TMP_DIR/wineGUI/wineGUI_glade || error "Can not create dir:" $TMP_DIR/wineGUI/wineGUI_glade
cp /usr/bin/distr_vendor $TMP_DIR/wineGUI/wineGUI_module/
# Достаем сырцы
cp $SRC_FILE $TMP_DIR
SRC_DIR_NAME=`basename $SRC_FILE`
SRC_DIR_NAME=${SRC_DIR_NAME:0:5}${SRC_DIR_NAME:21:8}
tar xvjf $TMP_DIR/`basename $SRC_FILE` -C $TMP_DIR/ $SRC_DIR_NAME/GUI > /dev/null
rm -f $TMP_DIR/`basename $SRC_FILE`

cp $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/wineGUI_module/*.py $TMP_DIR/wineGUI/wineGUI_module 
cp $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/wineGUI_glade/*.glade $TMP_DIR/wineGUI/wineGUI_glade
cp $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/wineGUI_glade/etersoft-logo.png $TMP_DIR/wineGUI/wineGUI_glade
cp -r $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/lang $TMP_DIR/wineGUI/
cp -r $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/diagnostics $TMP_DIR/wineGUI/
cp $TMP_DIR/$SRC_DIR_NAME/GUI/setup.sh $TMP_DIR
cp $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/main.py $TMP_DIR/wineGUI

# Создаем файл конфигурации
cp $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/config.src $TMP_DIR/wineGUI/config
sed -e "s|pkg_dir =|pkg_dir = ../PKG/|i" $TMP_DIR/wineGUI/config | \
sed -e "s|ver_date =|ver_date = $DATE_RELASE|i" | \
sed -e "s|linux_distrib =|linux_distrib = $LINUX_DISTRIB|i" | \
sed -e "s|linux_version =|linux_version = $LINUX_VERSION|i" | \
sed -e "s|wine_name =|wine_name = $type_product|i" | \
sed -e "s|test_mode =|test_mode = $is_test|i" | \
sed -e "s|owner =|owner = $owner|i" | \
sed -e "s|serial =|serial = $serial|i" | \
sed -e "s|gui_version =|gui_version = $WINE_VERSION|i" \
> $TMP_DIR/wineGUI/config

# Копируем файлы pygtk
copy_ok=0
for str in `cat $TMP_DIR/$SRC_DIR_NAME/GUI/pygtk.src`
do
if [ "$str" == "END" ]; then
	copy_ok=0
fi
if [ $copy_ok == 1 ]; then
	cp -r $str $TMP_DIR/wineGUI/wineGUI_module/pygtk
fi
tmp_str=`echo $str | grep $LINUX_DISTRIB/$LINUX_VERSION`
if [ "$tmp_str" != "" ]; then
	mkdir $TMP_DIR/wineGUI/wineGUI_module/pygtk || error "Can not create dir:" $TMP_DIR/wineGUI/wineGUI_module/pygtk
	copy_ok=1
fi
done

# Создаем файлы помощи
cp -r $TMP_DIR/$SRC_DIR_NAME/GUI/wineGUI/win_help.$type_product $TMP_DIR/wineGUI/win_help

# Удаляем временный каталог с исходниками и создаем конечный архив
rm -f -r $TMP_DIR/$SRC_DIR_NAME

makeself.sh --notemp --bzip2 $TMP_DIR setup WineEtersoft ./setup.sh

rm -f -r $TMP_DIR








