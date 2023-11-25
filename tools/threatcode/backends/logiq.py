import re
from .base import SingleTextQueryBackend
import json

class LogiqBackend(SingleTextQueryBackend):
    """Converts Threatcode rule into LOGIQ event rule api payload """
    identifier = "logiq"
    config_required = False
    active = True
    reEscape = re.compile('(")')
    reClear = None
    andToken = " && "
    orToken = " || "
    notToken = " !~ "
    subExpression = "%s"
    listExpression = "%s"
    listSeparator = ", "
    valueExpression = "message =~ \'%s\'"
    keyExpression = "%s"
    nullExpression = "!~ %s"
    notNullExpression = "!%s"
    mapExpression = "(%s=%s)"
    mapListsSpecialHandling = True

    reEscape = re.compile("([\\|()\[\]{}.^$+])")

    def generate(self, threatcodeparser):
        """Method is called for each threatcode rule and receives the parsed rule (ThreatcodeParser)"""

        eventRule = dict()
        eventRule["name"] = threatcodeparser.parsedyaml["title"]
        eventRule["groupName"] = threatcodeparser.parsedyaml["logsource"].get("product", "")
        eventRule["description"] = threatcodeparser.parsedyaml["description"]
        eventRule["condition"] = threatcodeparser.parsedyaml["detection"]
        eventRule["level"] = threatcodeparser.parsedyaml["level"]

        for parsed in threatcodeparser.condparsed:
            query = self.generateQuery(parsed)
            before = self.generateBefore(parsed)
            after = self.generateAfter(parsed)

            eventRule["condition"] = ""
            if before is not None:
                eventRule["condition"] = before
            if query is not None:
                eventRule["condition"] += query
            if after is not None:
                eventRule["condition"] += after

            return json.dumps(eventRule)

    def cleanValue(self, val):
        if val.startswith('*'):
            val = val.replace("*","/*")
      
        return val

    def generateListNode(self, node):
        if not set([type(value) for value in node]).issubset({str, int}):
            raise TypeError("List values must be strings or numbers")
        return self.generateORNode(node)
