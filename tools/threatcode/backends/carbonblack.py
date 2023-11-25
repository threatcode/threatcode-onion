import re
import requests
import json
import os
from threatcode.config.eventdict import event
from fnmatch import fnmatch

from threatcode.backends.base import SingleTextQueryBackend
from threatcode.backends.exceptions import NotSupportedError
from threatcode.parser.modifiers.type import ThreatcodeRegularExpressionModifier
from threatcode.parser.condition import ConditionOR, ConditionAND, NodeSubexpression

from threatcode.parser.modifiers.base import ThreatcodeTypeModifier
from threatcode.parser.modifiers.type import ThreatcodeRegularExpressionModifier


class CarbonBlackWildcardHandlingMixin:
    """
    Determine field mapping to keyword subfields depending on existence of wildcards in search values. Further,
    provide configurability with backend parameters.
    """

    # options = SingleTextQueryBackend.options + (
    #         ("keyword_field", None, "Keyword sub-field name", None),
    #         ("keyword_blacklist", None, "Fields that don't have a keyword subfield (wildcards * and ? allowed)", None)
    #         )
    reContainsWildcard = re.compile("(?:(?<!\\\\)|\\\\\\\\)[*?]").search

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.matchKeyword = True
        try:
            self.blacklist = self.keyword_blacklist.split(",")
        except AttributeError:
            self.blacklist = list()

    def containsWildcard(self, value):
        """Determine if value contains wildcard."""
        if type(value) == str:
            res = self.reContainsWildcard(value)
            return res
        else:
            return False


class CarbonBlackQueryBackend(CarbonBlackWildcardHandlingMixin, SingleTextQueryBackend):
    """Converts Threatcode rule into CarbonBlack query string. Only searches, no aggregations. Contributed by SOC Prime. https://socprime.com"""
    identifier = "carbonblack"
    active = True

    # reEscape = re.compile("([\s+\\-=!(){}\\[\\]^\"~:/]|(?<!\\\\)\\\\(?![*?\\\\])|\\\\u|&&|\\|\\|)")
    reEscape = re.compile("([\s\s+()\"])")
    reClear = re.compile("[<>]")
    andToken = " AND "
    orToken = " OR "
    notToken = " -"
    subExpression = "(%s)"
    listExpression = "(%s)"
    listSeparator = " OR "
    valueExpression = '%s'
    typedValueExpression = {ThreatcodeRegularExpressionModifier: "/%s/"}
    nullExpression = "NOT _exists_:%s"
    notNullExpression = "_exists_:%s"
    mapExpression = "%s:%s"
    mapListsSpecialHandling = False
    escapeCharacters = [
        '\\',
        '"',
        '\'',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ',',
        '=',
        '<',
        '>',
        '&',
        '|',
        ';',
        ':',
    ]

    def __init__(self, *args, **kwargs):
        """Initialize field mappings."""
        super().__init__(*args, **kwargs)
        self.category = None
        self.excluded_fields = None

    def cleanLeading(self, val):
        if val.startswith("*"):
            val = val[1:]
        if val.endswith("*"):
            val = val[:-1]
        return val.strip()

    def escapeCharacter(self, val):
        for ch in self.escapeCharacters:
            val = val.replace(ch, '\\' + ch)
        return val

    def unescapeCharacter(self, val):
        for ch in self.escapeCharacters:
            val = val.replace('\\' + ch, ch)
        return val

    def cleanWhitespace(self, val):
        val = val.replace('*', ' AND ').replace('  ', ' ')
        if re.match('\S+ \S', val):
            matchs = re.findall('(?:^|\(| )(.+?)(?:\)| OR| AND|$)', val)
            for strMatch in matchs:
                if re.match('\S+ \S', strMatch):
                    strUnescapeMatch = self.unescapeCharacter(strMatch)
                    val = val.replace(strMatch, '"{}"'.format(strUnescapeMatch))
        return val.strip()

    def cleanValue(self, val):
        if "[1 to *]" in val:
            self.reEscape = re.compile("([()])")
            val = super().cleanValue(val)
            val = val.strip()
        # else:
        #     self.reEscape = re.compile("([\s\s+()])")
        elif isinstance(val, str):
            val = val.strip()
            val = self.cleanLeading(val)
            val = self.escapeCharacter(val)
            val = self.cleanWhitespace(val)
        return val

    def cleanIPRange(self, value):
        new_value = value
        if isinstance(new_value, str) and value.find('*'):
            sub = value.count('.')
            if value[-2:] == '.*':
                value = value[:-2]
            min_ip = value + '.0' * (4 - sub)
            new_value = min_ip + '/' + str(8 * (4 - sub))
        elif isinstance(new_value, list):
            for index, vl in enumerate(new_value):
                new_value[index] = self.cleanIPRange(vl)

        return new_value

    def generateValueNode(self, node):
        result = self.valueExpression % (str(node))
        if result == "" or result.isspace():
            return '""'
        else:
            if self.matchKeyword:  # don't quote search value on keyword field
                return result
            else:
                return "%s" % result

    def generateMapItemNode(self, node):
        fieldname, value = node
        if fieldname == "EventID" and (type(value) is str or type(value) is int):
            fieldname = self.generateEventKey(value)
            value = self.generateEventValue(value)
        if fieldname.lower() in self.excluded_fields:
            return
        else:
            transformed_fieldname = self.fieldNameMapping(fieldname, value)
            if transformed_fieldname == "ipaddr":
                value = self.cleanIPRange(value)
            if (
                self.mapListsSpecialHandling == False
                and type(value) in (str, int, list)
                or self.mapListsSpecialHandling == True
                and type(value) in (str, int)
            ):
                # return self.mapExpression % (transformed_fieldname, self.generateNode(value))
                if isinstance(value, list):
                    return self.generateNode(
                        [
                            self.mapExpression
                            % (transformed_fieldname, self.cleanValue(item))
                            for item in value
                        ]
                    )
                elif isinstance(value, str) or isinstance(value, int):
                    return self.mapExpression % (
                        transformed_fieldname,
                        self.generateNode(self.cleanValue(value)),
                    )
            elif type(value) == list:
                return self.generateMapItemListNode(transformed_fieldname, value)
            elif isinstance(value, ThreatcodeTypeModifier) and not isinstance(
                value, ThreatcodeRegularExpressionModifier
            ):
                return self.generateMapItemTypedNode(transformed_fieldname, value)
            elif value is None:
                return self.nullExpression % (transformed_fieldname,)
            else:
                raise TypeError(
                    "Backend does not support map values of type " + str(type(value))
                )

    def generateNOTNode(self, node):
        expression = super().generateNode(node.item)
        if expression:
            return "(%s%s)" % (self.notToken, expression)

    # Function to upload watchlists through CB API

    def postAPI(self, result, title, desc):
        url = os.getenv("cbapi_watchlist")
        body = {
            "name": title,
            "search_query": "q=" + str(result),
            "description": desc,
            "index_type": "events",
        }
        header = {"X-Auth-Token": os.getenv("APIToken")}
        print(title)
        x = requests.post(url, data=json.dumps(body), headers=header, verify=False)
        print(x.text)

    def generateEventKey(self, value):
        if value in event:
            return event[value][0]
        else:
            return 'eventid'

    def generateEventValue(self, value):
        if value in event:
            return event[value][1]
        else:
            return ''

    def generate(self, threatcodeparser):
        """Method is called for each threatcode rule and receives the parsed rule (ThreatcodeParser)"""
        title = threatcodeparser.parsedyaml["title"]
        desc = threatcodeparser.parsedyaml["description"]
        try:
            self.category = threatcodeparser.parsedyaml['logsource'].setdefault(
                'category', None
            )
            self.counted = threatcodeparser.parsedyaml.get('counted', None)
            self.excluded_fields = [
                item.lower()
                for item in threatcodeparser.config.config.get("excludedfields", [])
            ]
        except KeyError:
            self.category = None
        for parsed in threatcodeparser.condparsed:
            query = self.generateQuery(parsed)
            result = ""

            if query is not None:
                result += query
                # self.postAPI(result,title,desc)
            return result
        # if self.category == "process_creation":
        #     for parsed in threatcodeparser.condparsed:
        #         query = self.generateQuery(parsed)
        #         result = ""

        #         if query is not None:
        #             result += query
        #         return result
        # else:
        #     raise NotSupportedError("Not supported logsource category.")
