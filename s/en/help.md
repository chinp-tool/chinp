# chinp Command Help

## Basic Commands

chinp                    Show all IPs
chinp -n 10              Show first 10 IPs
chinp -f                 Only failed attempts
chinp -t 5               Top 5 most frequent IPs
chinp -p 22              Only SSH connections
chinp -r                 Latest entries
chinp --anomalies        Anomalous activity

## All Options

-h, --help              Show help
-n, --limit N           Limit output to N records
-o, --output FILE       Save result to file
-f, --failed-only       Only failed attempts
-d, --date DATE         For specific date
-t, --top N             Top N most frequent IPs
-p, --port PORT         Filter by port
-r, --reverse           From end of log
-e, --exclude IP        Exclude IP
-b, --before DATE       Before date
--protocol TYPE         By protocol
--anomalies             Anomalous activity

## Examples

Show 5 IPs from port 22
chinp -p 22 -n 5

Save result to file
chinp -o result.txt

Show anomalies
chinp --anomalies

Combined query
chinp -f -p 22 -n 10
