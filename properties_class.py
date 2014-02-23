# Use with EM CLI

# EM CLI Set Target Properties Class
# Created by Seth Miller 2014/02
# Version 1.0


# This script is used in conjuction with Oracle Enterprise Manager EMCLI version 3
# interactive or scripting mode. It is a Python/Jython script and relies on the "emcli"
# module. The "re" module is loaded as well because the target filtering has the full
# capabilities of regular expressions.

# Importing this module will give you the "mySetProperties()" class. This script was
# originally designed to update the properties of a group of targets but in order
# to differentiate it from a standard EM CLI script that could do the same, the 
# advanced target filtering and target display functionality was added.

# Usage:

# Create a dictionary of the properties you want to set
# myprops = {'LifeCycle Status':'Development', 'Location':'COLO'}

# Create an instance of "mySetProperties()"
# mysetp = setp.mySetProperties()

# Look at the targets that a filter will match before making any changes
# mySetProperties(filter='^orcl_em12cr3').show()

# Set the instance filter
# mysetp.filt('^orcl_em12cr3.*[^(_sys)]$')

# Update the properties of the targets
# mysetp.setprops(myprops)

# Confirm the properties have been changed
# mysetp.show()




import emcli
import re

class mySetProperties():
    def __init__(self, filter='.*'):
        self.targs = [] # Instance target list
        self.filt(filter) # Regex filter for paring down targets list
    def filt(self, filter):
        self.targs = []
        # Compile the regex filter.
        __compfilt = re.compile(filter)
        # Create the "self.targs" list containing the filtered list of targets
        for __inttarg in emcli.list(resource='Targets').out()['data']:
            if __compfilt.search(__inttarg['TARGET_NAME']):
                self.targs.append(__inttarg)
    def show(self):
        # Create the "self.targprops" list containing the full list of target properties
        self.targprops = emcli.list(resource='TargetProperties').out()['data']
        print('%-5s%-40s%s' % (' ', 'TARGET_TYPE'.ljust(40, '.'), 'TARGET_NAME'))
        print('%-15s%-30s%s\n%s\n' % (' ', 'PROPERTY_NAME'.ljust(30, '.'), 'PROPERTY_VALUE', '=' * 80))
        for __inttarg in self.targs:
            print('%-5s%-40s%s' % (' ', __inttarg['TARGET_TYPE'].ljust(40, '.'),  __inttarg['TARGET_NAME']))
            self.__showprops(__inttarg['TARGET_GUID'])
            print('')
    def setprops(self, props):
        # props needs to be a dictionary of {'property_name':'property_value'}
        assert isinstance(props, dict), 'setprops(props) parameter must be a dictionary of {"property_name":"property_value"}'
        __delim = '@#&@#&&' # Very randomized delimiter to make sure there is no collisions
        __subseparator = 'property_records=' + __delim
        for __inttarg in self.targs:
            # Iterate through the properties dictionary
            for __propkey, __propvalue in props.items():
                # Will look like this: em12cr3.example.com:3872@#&@#&&oracle_emd@#&@#&&Comment@#&@#&&yermom
                __property_records = __inttarg['TARGET_NAME'] + __delim + __inttarg['TARGET_TYPE'] + \
                                     __delim + __propkey + __delim + __propvalue 
                print('Target: ' + __inttarg['TARGET_NAME'] + ' (' + __inttarg['TARGET_TYPE'] + ')\n\tProperty: '
                      + __propkey + '\n\tValue:    ' + __propvalue + '\n')
                emcli.set_target_property_value(subseparator=__subseparator, property_records=__property_records)
    def __showprops(self, guid):
        for __inttargprops in self.targprops:
            __intpropname = __inttargprops['PROPERTY_NAME'].split('_')
            if __inttargprops['TARGET_GUID'] == guid and __intpropname[0:2] == ['orcl', 'gtp']:
                print('%-15s%-30s%s' % (' ', ' '.join(__intpropname[2:]).ljust(30, '.'), __inttargprops['PROPERTY_VALUE']))
