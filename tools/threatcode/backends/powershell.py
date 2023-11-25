# Output backends for threatcodec
# Copyright 2016-2018 Md Sulaiman, Florian Roth, Roey, Karneades

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import re
import threatcode
from .base import SingleTextQueryBackend
from .mixins import MultiRuleOutputMixin

class PowerShellBackend(SingleTextQueryBackend):
    """Converts Threatcode rule into PowerShell event log cmdlets."""
    identifier = "powershell"
    active = True
    config_required = False
    default_config = ["sysmon", "powershell"]
    options = (
        ("csv", False, "Return the results in CSV format instead of Powershell objects", None),
    )

    reEscape = re.compile('("|(?<!\\\\)\\\\(?![*?\\\\])|\+)')
    reClear = None
    andToken = " -and "
    orToken = " -or "
    notToken = " -not "
    subExpression = "(%s)"
    listExpression = "($_.message -match %s)"
    listSeparator = "$_.message -match "
    valueExpression = "\"%s\""
    nullExpression = "-not %s=\"*\""
    notNullExpression = "%s=\"*\""
    mapExpression = "$_.%s -eq %s"
    mapListsSpecialHandling = True

    logname = None

    def generate(self, threatcodeparser):
        """Method is called for each threatcode rule and receives the parsed rule (ThreatcodeParser)"""
        for parsed in threatcodeparser.condparsed:
            query = self.generateQuery(parsed, threatcodeparser)
            before = self.generateBefore(parsed)
            after = self.generateAfter(parsed)

            result = ""

            if before is not None:
                result = before
            if query is not None:
                result += query
            if after is not None:
                result += after

            return result

    def generateBefore(self, parsed):
        if self.logname:
            return "Get-WinEvent -LogName %s | where {" % self.logname
        return "Get-WinEvent | where {"

    def generateAfter(self, parsed):
        if self.csv:
            return " | ConvertTo-CSV -NoTypeInformation"
        return ""

    def generateNode(self, node):
        if type(node) == threatcode.parser.condition.ConditionAND:
            return self.generateANDNode(node)
        elif type(node) == threatcode.parser.condition.ConditionOR:
            return self.generateORNode(node)
        elif type(node) == threatcode.parser.condition.ConditionNOT:
            return self.generateNOTNode(node)
        elif type(node) == threatcode.parser.condition.ConditionNULLValue:
            return self.generateNULLValueNode(node)
        elif type(node) == threatcode.parser.condition.ConditionNotNULLValue:
            return self.generateNotNULLValueNode(node)
        elif type(node) == threatcode.parser.condition.NodeSubexpression:
            return self.generateSubexpressionNode(node)
        elif type(node) == tuple:
            return self.generateMapItemNode(node)
        elif type(node) in (str, int):
            return self.generateValueNode(node, False)
        elif type(node) == list:
            return self.generateListNode(node)
        else:
            raise TypeError("Node type %s was not expected in Threatcode parse tree" % (str(type(node))))

    def generateQuery(self, parsed, threatcodeparser):
        result = self.generateNode(parsed.parsedSearch)
        self.parsedlogsource = threatcodeparser.get_logsource().service

        powershellPrefix = ""
        if parsed.parsedAgg:
            powershellSuffixAgg = self.generateAggregation(parsed.parsedAgg)
            result = result + " } " + powershellSuffixAgg
        else:
            result = powershellPrefix + result + " } | select TimeCreated,Id,RecordId,ProcessId,MachineName,Message"
        return result

    def generateMapItemNode(self, node):
        key, value = node
        if self.mapListsSpecialHandling == False and type(value) in (str, int, list) or self.mapListsSpecialHandling == True and type(value) in (str, int):
            if key in ("LogName","source"):
                self.logname = value
            elif key in ("ID", "EventID"):
                if key == "EventID":
                    key = "ID"
                return self.mapExpression % (key, self.generateValueNode(value, True))
            elif type(value) == str and "*" in value:
                value = value.replace("*", ".*")
                if key == "Message":
                    return "$_.message -match %s" % (self.generateValueNode(value, True))
                else:
                    return "$_.message -match %s" % (self.generateValueNode(key + ".*" + value, True))
            elif type(value) in (str, int):
                return '$_.message -match %s' % (self.generateValueNode(key + ".*" +str(value), True))
            else:
                return self.mapExpression % (key, self.generateNode(value))
        elif type(value) == list:
            return self.generateMapItemListNode(key, value)
        elif value is None:
            return self.nullExpression % (key, )
        else:
            raise TypeError("Backend does not support map values of type " + str(type(value)))

    def generateMapItemListNode(self, key, value):
        itemslist = list()
        for item in value:
            if key in ("ID", "EventID"):
                if key == "EventID":
                    key = "ID"
                itemslist.append(self.mapExpression % (key, self.generateValueNode(item, True)))
            elif type(item) == str and "*" in item:
                item = item.replace("*", ".*")
                if key == "Message":
                    itemslist.append('$_.message -match %s' % (self.generateValueNode(item, True)))
                else:
                    itemslist.append('$_.message -match %s' % (self.generateValueNode(key + ".*" +item, True)))
            else:
                itemslist.append('$_.message -match %s' % (self.generateValueNode(item, True)))
        return '('+" -or ".join(itemslist)+')'

    def generateANDNode(self, node):
        generated = [ self.generateNode(val) for val in node ]
        filtered = [ g for g in generated if g is not None ]
        if filtered:
            return self.andToken.join(filtered)
        else:
            return None

    def generateValueNode(self, node, keypresent):
        if keypresent == False:
            return "$_.message -match \"{0}\"".format(str(node))
        else:
            return self.valueExpression % (self.cleanValue(str(node)))

    def getPowerShellCondOp(self, cond_op):
        if(cond_op == "<"):
            return "-lt"
        elif(cond_op == ">"):
            return "-gt"
        elif(cond_op == "="):
            return "-eq"

    def generateAggregation(self, agg):
        if agg == None:
            return ""
        if agg.aggfunc != threatcode.parser.condition.ThreatcodeAggregationParser.AGGFUNC_COUNT:
            raise NotImplementedError("Only COUNT aggregation function is implemented for this backend")
        if agg.aggfunc == threatcode.parser.condition.ThreatcodeAggregationParser.AGGFUNC_NEAR:
            # python .\tools\threatcodec -t splunk -c .\tools\config\splunk-windows-all.yml -r .\rules\windows\builtin\
            # Example rule: .\threatcode\rules\windows\builtin\win_susp_samr_pwset.yml
            raise NotImplementedError("The 'near' aggregation operator is not yet implemented for this backend")
        if agg.groupfield == None:
            # Example rule: .\threatcode\rules\windows\builtin\win_multiple_suspicious_cli.yml
            powershell_cond_op = self.getPowerShellCondOp(agg.cond_op)
            return " | group-object %s | where { $_.count %s %s } | select name,count | sort -desc" % (agg.aggfield or "", powershell_cond_op, agg.condition)
        else:
            # Example rule: .\threatcode\rules\windows\other\win_rare_schtask_creation.yml
            powershell_cond_op = self.getPowerShellCondOp(agg.cond_op)
            if (agg.aggfield == None):
                return " | group-object %s | where { $_.count %s %s } | select name,count | sort -desc" % (agg.groupfield or "", powershell_cond_op, agg.condition)
            else:
                return " | select %s, %s | group %s | foreach { [PSCustomObject]@{'%s'=$_.name;'Count'=($_.group.%s | sort -u).count} }  | sort count -desc | where { $_.count %s %s }" % (agg.groupfield, agg.aggfield, agg.groupfield, agg.groupfield, agg.aggfield, powershell_cond_op, agg.condition)
