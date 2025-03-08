import xml.etree.ElementTree as ET
import os, re, sys


RESULT_PATH='/data/victoryplusdev/source/integration-testing/results/wsresult/'
TotalPass = 0
TotalFail = 0

def find_test_html_log(directory, casename):
    """
    Searches for HTML files in the given directory and its subdirectories. Returns a list of the file paths.
    If the casename is provided, only HTML files containing the casename in their filename will be returned.
    """
    file_paths = []

    if directory is None or not os.path.isdir(directory):
        raise ValueError(
            "The directory given is not a valid directory. Please provide a valid directory.")

    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)

        if os.path.isdir(file_path):
            file_paths.extend(find_test_html_log(file_path, casename))
        elif filename.endswith('.html') and (casename is None or re.search(casename, filename)):
            file_paths.append(file_path)

    return file_paths


def parse_resultxml(result_path, filename, results):
    resultfile = os.path.join(result_path, filename)
    # Open and parse the XML file
    tree = ET.parse(resultfile)
    root = tree.getroot()
    tests = root.get('tests')
    global TotalPass, TotalFail
      # Iterate through all the testcases
    for testcase in root:
        # Access the attributes and text of each testcase
        classname = testcase.get('classname')
        shortname = classname.split('.')[-1]
        file = testcase.get('file')
        line = testcase.get('line')
        name = testcase.get('name')
        time = testcase.get('time')
        error = 0
        errormessage = ''
        for child in testcase:
            error += 1
            errormessage += child.text
        logfiles = find_test_html_log(result_path, shortname)

        if error == 0:
            testresult = 'PASS'
            TotalPass += 1
        else:
            testresult = 'FAIL'
            TotalFail += 1
        results.append({
            'casename': shortname,
            'classname': classname,
            'time': time,
            'testresult': testresult,
            'errornum': error,
            'errormessage': errormessage,
            'logfile': logfiles
            })


def generate_html_report(result_path, filename, results):
    output_file = os.path.join(result_path, filename)
    global TotalPass, TotalFail
    html_output = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Test Report</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 0;
                height: 100vh;
            }

            h1 {
                text-align: center;
                margin: 20px;
                font-size: 24px;
            }

            p {
                margin: 20px;
            }

            table {
                border-collapse: collapse;
                margin: 20px;
                padding: 20px;
                font-size: 16px;
            }

            th, td {
                border: 1px solid #dddddd;
                text-align: left;
                padding: 8px;
            }

            th {
                background-color: #f2f2f2;
            }

            tr:nth-child(even) {
                background-color: #f9f9f9;
            }
            tr:hover {
                background-color: #f5f5f5;
            }

            tr.fail {
                background-color: #ffcccc;
            }
        </style>
    </head>
    <body>
        <h1>Test Report</h1>
    """
    html_output += f"""
        <p>
            Total Pass: <b>{TotalPass}</b>
            Total Fail: <b>{TotalFail}</b><br/>
        </p>
        <table>
            <tr>
                <th>Case Name</th>
                <th>Time</th>
                <th>Test Result</th>
                <th>Error Number</th>
                <th>Error Message</th>
                <th>Log File</th>
            </tr>
    """

    for result in results:
        if result['testresult'] == 'FAIL':
            html_output += "<tr class=fail>"
        else:
            html_output += "<tr>"
        errormessage = result['errormessage'].replace('\n', '<br/>')
        html_output += f"""
                <td>{result['casename']}</td>
                <td>{result['time']}</td>
                <td>{result['testresult']}</td>
                <td>{result['errornum']}</td>
                <td>{errormessage}</td>
                <td>
        """
        for file in result['logfile']:
            url = file[len(result_path):]
            if url.startswith('/'):
                url = url[1:]
            html_output += f"""
                <a href="{url}">{url}</a><br/>
            """
        html_output += """
                </td>
            </tr>
        """

    html_output += """
        </table>
    </body>
    </html>
    """

    with open(output_file, 'w') as file:
        file.write(html_output)

    print(f"HTML report written to {output_file}")

    return html_output
def main():
    # Check if any arguments were passed
    if len(sys.argv) > 1:
        # Get the first argument
        result_path = sys.argv[1]
        print("Finding results in path:", result_path)
    else:
        print("Result path must pass!")
        exit(1)
    results=[]
    # Iterate through all the files in the directory
    for filename in os.listdir(result_path):
        if filename.endswith('.xml'):
            # Call the function to parse the XML file
            parse_resultxml(result_path, filename, results)
    sortedresult = sorted(results, key=lambda x: x['logfile'][-1])
    generate_html_report(result_path, "testreport.html", sortedresult)

if __name__ == "__main__":
    main()

  
