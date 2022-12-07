#!/bin/bash

##
##  GrayMetric
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

## Dependencies: Bash, cURL, Netcat, jq


# Would like to know who and where I am.
SCRIPTPATH=$(dirname "$0")
SCRIPTNAME=$(basename "$0")

# See if there's somebody knocking on stdin, if yes, let 'em in.
if read -t 0; then

	STIN=$(cat -)

fi
# Yeah, cat content always works!


# You can put your token here. Just omit -t|-T then.
gl_token=""
gl_pass="token"

# Put your Graylog API URL here, then omit -u
gl_api_url="http://127.0.0.1:9000/api/"

# Custom cURL options. The -k ignores SSL certificate checks
COPTS="-k"

# If you put your metrics list here, you don't need to put it
# on the command line. Remember -m to merge if you want to or
# you persist merge metrics below.
gl_metric_list="${SCRIPTPATH}/graylog_metric_examples.txt"

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
	echo
	echo "========================================="
	echo
	echo "  GrayMetric - Fetching Graylog Metrics"
	echo
	echo "========================================="
	echo
	echo "(c) 2022 Christian B. Caldarone"
	echo
	echo
	echo "License: Apache License 2.0"
	echo
	echo
	echo "Usage:"
	echo
	echo "      ${SCRIPTNAME} -t <TOKEN> | -u <URL> -m -f <PATH_TO_METRIC_LIST> -o <GRAYLOG_RAW_INPUT:PORT>"
	echo
	echo "       Accepts a list of Graylog metrics (one per line) as input from stdin"
	echo
	echo "       -t  <TOKEN>  is the Graylog token, generated for a specific user (required)"
	echo "       -T  <PATH_TO_TOKEN>  alternatively reads the Graylog token from a file"
	echo "       -u  <URL>  is the Graylog API URL, if omitted, http://127.0.0.1:9000/api/ will be used"
	echo "       -f  <PATH_TO_METRIC_LIST>  a text file to read Graylog metric names from, one per line"
	echo "       -o  <GRAYLOG_RAW_INPUT:PORT>  hostname/ip and port of the Graylog raw input to send the metrics"
 	echo "       -m  if the metrics list is provided through stdin AND the -f option is used to provide a file"
 	echo "           as well, stdin will replace the information provided by the file as default. Now With the -m"
	echo "           option, you can merge them together"
	echo "       -L  <TEXT> creates a field 'label' with the text provided. If omitted the field is not created"
	echo "       -h  Shows this help"
	echo
	echo "       Examples:"
	echo
	echo "       cat metric_list.txt | ./${SCRIPTNAME} -o \"127.0.0.1:5565\" -m -f \"/home/user/additional_metrics.txt\""
	echo
	echo "       ./${SCRIPTNAME} -f \"my_gl_metrics.txt\" -L \"prod_pipelines\" -t <TOKEN>"
	echo
	echo "       ./${SCRIPTNAME} -t "'${gl_token}'" < graylog_metric_collection.txt"
	echo
	echo "       echo \"org.graylog2.journal.entries-uncommitted\" | ./${SCRIPTNAME} -T ~/mytoken.txt -o \"192.168.1.1:5565\""
	echo
	echo
	exit
	;;

    o ) # Output to Graylog raw input
	gl_out_raw="TRUE"

	if [[ -z "$OPTARG" ]]; then

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
	exit
        ;;

   \? ) # Handle invalid options
	echo "Invalid option. Better fix it."
	exit
	;;
  esac

done

# Show your papers
if [[ -z "${gl_token}" ]]; then

	echo "No Graylog API access token provided (see command line option -t or -T)"
	echo "See ya."
	exit

fi


# Get the metrics together and merge them if asked for. Clean them up, distill them, look
# for duplicates and put them in order. Tidy, isn't it?
gl_metric_items="$({

if [[ "${STIN}" ]]; then

	echo "${STIN}"

fi


if ([[ "${gl_merge_metrics}" == "TRUE" ]] && [[ "${gl_metric_list}" ]]) || ! [[ "${STIN}" ]]; then

	echo "$(cat "${gl_metric_list}")"

fi

} | tr -d ' ' | grep -iP "^org.graylog" | sort -u)"


mapfile -t <<< "${gl_metric_items}"

METRICS=$(
for item in ${MAPFILE[@]}
        do
                echo -n "\"${item}\","
        done
)


RESP=$(curl "${COPTS}" -s -X GET -u "${gl_token}:${gl_pass}" -H 'Accept: application/json; charset=utf-8' -H 'X-Requested-By: GrayMon' "${gl_api_url}system")

NODE_ID=$(jq -r '.node_id' <<< ${RESP})

CLUSTER_ID=$(jq -r '.cluster_id' <<< ${RESP})



RESP=$(curl "${COPTS}" -s -X POST -u "${gl_token}:${gl_pass}" -H 'Content-Type: application/json' -H 'Accept: application/json; charset=utf-8' -H 'X-Requested-By: GrayMon' \
-d "{\"metrics\":["${METRICS%?}"]}" "${gl_api_url}cluster/"${NODE_ID}"/metrics/multiple")


i=0

COUNT=$(jq -r '.total' <<< ${RESP})


until [ $i = $COUNT ]
do

METRIC_TYPE=$(jq -r '.metrics['"$i"'] | objects | .type' <<< ${RESP} | tr '[:upper:]' '[:lower:]')
METRIC_NAME=$(jq -r '.metrics['"$i"'] | objects | .full_name' <<<"${RESP}" | cut -f 3- -d ".")

MESSAGE=$(jq -r '.metrics['"$i"'] | objects | .full_name' <<<"${RESP}")

json_line=$({

echo "{\"node_id\": \"${NODE_ID}\"}"

echo "{\"node_hostname\": \"$(printf $(hostname))\"}"

echo "{\"node_ip\": \"$(printf $(hostname -I))\"}"

echo "{\"cluster_id\": \"${CLUSTER_ID}\"}"

echo "{\"timestamp\": $(date +%s)}"

echo "{\"source\": \"${gl_source_field}\"}"

echo "{\"metric_name\": \"${METRIC_NAME}\"}"

echo "{\"message\": \"${MESSAGE}\"}"

if [[ "${gl_label_field}" ]]; then

	echo "{\"label\": \"${gl_label_field}\"}"
fi



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



if [[ "${gl_out_raw}" == "TRUE" ]]; then

	echo "${json_line}" | nc "${gl_out_host}" "${gl_out_port}"

else

	echo "${json_line}"

fi


(( i++ ))

done
