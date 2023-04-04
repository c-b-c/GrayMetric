#!/bin/bash

##
##  GrayMetric
##
##  Version 1
##
##  Bash approach to fetch metrics from Graylog, reformat and restyle them preserving the JSON format.
##  The output of GrayMetric can be sent directly to a Graylog raw/tcp input to be then visually prepared
##  in a dashboard, further processed by streams and piplelines or alternatively used in any other
##  application being able to understand JSON and analytics.
##
##  (c) 2022 Christian B. Caldarone
##
##  License: Apache License 2.0
##

## Dependencies: Bash, cURL, Nmap-Netcat, jq, dig


# Would like to know who and where I am.
SCRIPTPATH=$(dirname "$0")
SCRIPTNAME=$(basename "$0")
SCRIPTVERSION="1.03"


# See if there's somebody knocking on stdin, if yes, let 'em in.
if read -t 0; then

        STIN="$(cat -)"

fi


# Before we continue, let's check the command dependencies of this script
# If the required binaries are not present in your system. I'm afraid I've
# to quit here!

dependencies=( curl jq ncat dig)

for dependency in "${dependencies[@]}"

do

	command -v "$dependency" >/dev/null 2>&1 || { echo >&2 "\"$dependency\" is required, but not installed. I'm quitting."; exit 65; }

done


# Depending on your netcat version, it might be necessary to add more options here or change them
# Non nmap-netcat implementations seem not to close the connection  after sending, so it looks like
# it hangs.
#
# Read here for an explanation and solution:
#
# https://serverfault.com/questions/512722/how-to-automatically-close-netcat-connection-after-data-is-sent

if ! [[ "$(ncat --help | grep -is 'nmap')" ]]; then

	NCOPTS="-w 1"

else

	NCOPTS=""

fi


# You can put your token here or in a file called 'token.txt'. Just omit -t|-T then. gl_token represents
# the username and gl_pass the password. You could also put regular Graylog user credentials in, but that's
# no recommended.
gl_token=""
gl_pass="token"

# Put your Graylog API URL here, then omit -u
gl_api_url="http://127.0.0.1:9000/api/"

# Custom cURL options. The -k ignores SSL certificate checks
COPTS="-k"

# If you put your metrics list here, you don't need to put it
# on the command line. Remember -m to merge if you want to or
# you persist merge metrics below.
# gl_metric_list="${SCRIPTPATH}/graylog_metric_examples.txt"
gl_metric_list=""

gl_merge_metrics="FALSE"

# This is the output for Graylog's raw tcp input, but you can
# send it elsewhere. It is just plain JSON over tcp. If FALSE
# all will be put out on stdout ... or use -o on command line.
gl_out_raw="FALSE"
gl_out_host="127.0.0.1"
gl_out_port="5565"

# The following things can be also pre-set here, you adjust
# them to your needs. You could even add your own stuff.
gl_source_field="$(hostname -s)"
gl_label_field=""


# Guess it's time now to see who queued up in the options queue
while getopts ':u:t:T:f:ho:mc:L:x:' OPTION ; do

  case "$OPTION" in
    u ) # Get the Graylog API URL
	gl_api_url="$OPTARG"
	;;

    t ) # Get the Graylog API Token as commandline argument
	gl_token="$OPTARG"
	;;

    T ) # Get the Graylog API Token from a file
        gl_token=$(cat "$OPTARG")
	#gl_token=$(cut -f 1 -d ":" <<< "$OPTARG")
        #gl_pass=$(cut -f 2 -d ":" <<< "$OPTARG")
        ;;
    c ) # Get the Graylog API credentials as user:password from a file (format is user:password)
        OPTARG=$(cat "$OPTARG")
        gl_token=$(cut -f 1 -d ":" <<< "$OPTARG")
        gl_pass=$(cut -f 2 -d ":" <<< "$OPTARG")
        ;;

    L ) # Creat and use a Label field to be injected into the metrics JSON
        gl_label_field="$OPTARG"
        ;;

    f ) # Get a list of all the metrics to fetch
	gl_metric_list="$OPTARG"
	;;
    h ) # Show some useful help
	echo \
"
=========================================

  GrayMetric - Fetching Graylog Metrics

  Version: ${SCRIPTVERSION}

  License: Apache License 2.0

=========================================

 (c) 2023 Christian B. Caldarone


 	Usage:

	Accepts a list of Graylog metrics (one per line) as input from stdin

	-t  <TOKEN>  is the Graylog token, generated for a specific user (required)
        -T  <PATH_TO_TOKEN>  alternatively reads the Graylog token from a file
        -u  <URL>  is the Graylog API URL, if omitted, http://127.0.0.1:9000/api/ will be used
        -f  <PATH_TO_METRIC_LIST>  a text file to read Graylog metric names from, one per line
        -o  <GRAYLOG_RAW_INPUT:PORT>  hostname/ip and port of the Graylog raw input to send the metrics
        -m  if the metrics list is provided through stdin AND the -f option is used to provide a file
            as well, stdin will replace the information provided by the file as default. Now With the -m
            option, you can merge them together
        -L  <TEXT> creates a field 'label' with the text provided. If omitted the field is not created
        -h  Shows this help

	Examples:

	cat metric_list.txt | ./${SCRIPTNAME} -o \"127.0.0.1:5565\" -m -f \"/home/user/additional_metrics.txt\"

	./${SCRIPTNAME} -f \"my_gl_metrics.txt\" -L \"prod_pipelines\" -t <TOKEN> -u \"http://10.1.1.1:9000/api/\"

	./${SCRIPTNAME} -t \"${gl_token}\" < graylog_metric_collection.txt

        echo \"org.graylog2.journal.entries-uncommitted\" | ./${SCRIPTNAME} -T ~/mytoken.txt -o \"192.168.1.1:5565\"

"
	exit 0
	;;

    o ) # Output to Graylog raw input
	gl_out_raw="TRUE"

	if [[ ! -z "$OPTARG" ]]; then

		gl_out_host=$(cut -f 1 -d ":" <<< "$OPTARG")
		gl_out_port=$(cut -f 2 -d ":" <<< "$OPTARG")
	fi
	;;

    m ) # Control if stdin and file metrics are merged and unified
	gl_merge_metrics="TRUE"
	;;

    x ) # Placeholder switch for future customizations
        x_switch="TRUE"
	echo
	echo "*** YOU FOUND THE SECRET MENU!!! ***"
	echo
	echo "Thanks for telling us about ${OPTARG}"
	echo
	echo "We're going to transfer USD 1.000.000.000 to your bank account right now."
	echo
	echo
	read -p "Press enter to get rich"
	exit 130
        ;;

   : ) # Handle missing options argument
        echo "There's something missing!"
	echo "Check where you need to provide an option argument"
        exit 61
        ;;


   \? ) # Handle invalid options
	echo "Invalid option. Better fix it."
	exit 22
	;;
  esac

done

# Show your papers
if [[ -z "${gl_token}" ]]; then

	# That is also an option: Just put the token in a 'token.txt' file an store in in the script's path
	if [[ -f "${SCRIPTPATH}/token.txt" ]]; then

		gl_token="$(cat ${SCRIPTPATH}/token.txt)"

	else

		echo "No Graylog API access token provided (see command line option -t or -T) or put it into \"${SCRIPTPATH}/token.txt)\""
		echo "See ya."
		exit 126

	fi

fi


if [[ "${gl_merge_metrics}" == "TRUE" ]] || ! [[ "${STIN}" ]]; then


	if ! [[ "${gl_metric_list}" ]]; then

		echo "You didn't bring any metrics with you. What are you here for?"
		exit 61

	elif ! [[ -f "${gl_metric_list}" ]]; then

                echo "The metrics file \"${gl_metric_list}\" is not there. Looks like you've a hole in your pocket"
                exit 2

	fi

fi


# Get the metrics together and merge them if asked for. Clean them up, distill them, look
# for duplicates and put them in order. Tidy, isn't it?
gl_metric_items="$({

if [[ "${STIN}" ]]; then

	echo "${STIN}"

fi


if ( [[ "${gl_merge_metrics}" == "TRUE" ]] || ! [[ "${STIN}" ]] ) && [[ "${gl_metric_list}" ]]; then


	cat "${gl_metric_list}"

fi

} | tr -d ' ' | grep -iP "^org.graylog" | sort -u)"


mapfile -t <<< "${gl_metric_items}"

METRICS=$(
for item in ${MAPFILE[@]}
        do
                echo -n "\"${item}\","
        done
)


# Check if someone was too sloppy minding the slash.

if ! [[ "${gl_api_url: -1}" == "/" ]]; then

	gl_api_url="${gl_api_url}/"

fi


# First: Get some Graylog node and cluster info off the api, this is used to enrich the meta data

RESP=$(curl "${COPTS}" -s -X GET -u "${gl_token}:${gl_pass}" -H 'Accept: application/json; charset=utf-8' -H 'X-Requested-By: GrayMetric' "${gl_api_url}system")

if [[ -z "${RESP}" ]]; then

        echo "Got nothing back fromn the Graylog API: \"${gl_api_url}\"."
	echo "Are you sure things work? Please check URL, Token, Firewall..."
        exit 61

fi


NODE_ID=$(jq -r '.node_id' <<< ${RESP})

NODE_HOSTNAME=$(jq -r '.hostname' <<< ${RESP})

CLUSTER_ID=$(jq -r '.cluster_id' <<< ${RESP})


# Second: Get all the metrics from the shopping list off the shelf and put them into the caddy.

RESP=$(curl "${COPTS}" -s -X POST -u "${gl_token}:${gl_pass}" -H 'Content-Type: application/json' -H 'Accept: application/json; charset=utf-8' -H 'X-Requested-By: GrayMetrics' \
-d "{\"metrics\":["${METRICS%?}"]}" "${gl_api_url}cluster/"${NODE_ID}"/metrics/multiple")


# See what we've got in the caddy and put stuff on the belt. Yay! We're ready for checkout.
i=0

COUNT=$(jq -r '.total' <<< ${RESP})

if [[ $COUNT ]]; then

until [ $i = $COUNT ]
do

METRIC_TYPE=$(jq -r '.metrics['"$i"'] | objects | .type' <<< ${RESP} | tr '[:upper:]' '[:lower:]')
METRIC_NAME=$(jq -r '.metrics['"$i"'] | objects | .full_name' <<<"${RESP}" | cut -f 3- -d ".")

MESSAGE=$(jq -r '.metrics['"$i"'] | objects | .full_name' <<<"${RESP}")

json_line=$({

echo "{\"node_id\": \"${NODE_ID}\"}"

echo "{\"node_hostname\": \"${NODE_HOSTNAME}\"}"

echo "{\"node_ip\": \"$(dig +short $NODE_HOSTNAME)\"}"

echo "{\"cluster_id\": \"${CLUSTER_ID}\"}"

echo "{\"timestamp\": $(date +%s)}"

echo "{\"source\": \"${gl_source_field}\"}"

echo "{\"metric_name\": \"${METRIC_NAME}\"}"

echo "{\"message\": \"${MESSAGE}\"}"

if [[ "${gl_label_field}" ]]; then

	echo "{\"label\": \"${gl_label_field}\"}"
fi

# Differentiate between some metrics families here. They need some individual treatment.

if [ "$METRIC_TYPE" = "meter" ]; then

	jq  '.metrics['"$i"'] | .metric.rate | with_entries( .key |="metric_\(.)")' <<<"${RESP}"

	jq  '.metrics['"$i"'] | {metric_rate_unit: .metric.rate_unit}' <<<"${RESP}"
fi

if [ "$METRIC_TYPE" = "gauge" ]; then

	jq  '.metrics['"$i"'] | {metric_gauge_value: .metric.value}' <<<"${RESP}"
fi

if [ "$METRIC_TYPE" = "counter" ]; then

        jq  '.metrics['"$i"'] | {metric_count: .metric.count}' <<<"${RESP}"

fi

if [ "$METRIC_TYPE" = "timer" ]; then

        jq  '.metrics['"$i"'] | .metric.time | with_entries( .key |="metric_time_\(.)")' <<<"${RESP}"

	jq  '.metrics['"$i"'] | .metric.rate | with_entries( .key |="metric_rate_\(.)")' <<<"${RESP}"

        jq  '.metrics['"$i"'] | {metric_rate_unit: .metric.rate_unit}' <<<"${RESP}"

	jq  '.metrics['"$i"'] | {metric_time_duration_unit: .metric.duration_unit}' <<<"${RESP}"

fi

if [ "$METRIC_TYPE" = "histogram" ]; then

        jq  '.metrics['"$i"'] | .metric.time | with_entries( .key |="metric_time_\(.)")' <<<"${RESP}"

	jq  '.metrics['"$i"'] | {metric_count: .metric.count}' <<<"${RESP}"

fi


echo "{\"metric_type\": \"${METRIC_TYPE}\"}"


} | jq -s -c 'add')



# Finally we're done. Let's throw stuff into the trunk .

if [[ "${gl_out_raw}" == "TRUE" ]]; then


	if [[ ! -z "${NCOPTS}" ]]; then

		echo "${json_line}" | ncat "${NCOPTS}" "${gl_out_host}" "${gl_out_port}"

	else

		echo "${json_line}" | ncat "${gl_out_host}" "${gl_out_port}"

	fi

else

	echo "${json_line}"

fi


(( i++ ))

done

# OK, great. We can drive home now.

fi
