# GrayMetric
Bash approach to fetch metrics from Graylog, reformat and restyle them, preserving the JSON format. 

You can use this command line tool to fetch metrics from the Graylog API and then further process and forward them.
The built-in output allows you to feed them back into Graylog using a raw/tcp input. It is then recommended to create
a stream, where you route them all in. Now it is pretty easy to build dashbaords based on the metrics. They are all
there as key/value pairs. No normalization or parsing needed. If you want to process the metrics through another system,
is quite easy as well: The output is pure JSON to stdin if you omit the "-o server:port" option. You can then pipe the
output through curl to Elasticsearch or other tools like MongoDB CLI to have it stored in there.


      
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
	
        cat metric_list.txt | ./graymetric.sh -o "127.0.0.1:5565" -m -f "/home/user/additional_metrics.txt"

        ./graymetric.sh -f "my_gl_metrics.txt" -L "prod_pipelines" -t <TOKEN> -u "http://10.1.1.1:9000/api/"
	
        ./graymetric.sh -t "" < graylog_metric_collection.txt

        echo "org.graylog2.journal.entries-uncommitted" | ./graymetric.sh -T ~/mytoken.txt -o "192.168.1.1:5565"
