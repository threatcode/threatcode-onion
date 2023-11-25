# Setup module for Threatcode toolchain
# derived from example at https://github.com/pypa/sampleproject/blob/master/setup.py
from setuptools import setup, find_packages
# To use a consistent encoding
from codecs import open
from os import path
from pathlib import Path

here = path.abspath(path.dirname(__file__))

# Get the long description from the README file
with open(path.join(here, 'LONG_DESCRIPTION.md'), encoding='utf-8') as f:
    long_description = f.read()

setup(
    name='khulnasoft',
    version='0.0.1',
    description='Tools for the Generic Signature Format for SIEM Systems',
    long_description=long_description,
    long_description_content_type="text/markdown",
    url='https://github.com/threatcode/threatcode',
    author='Threatcode Project',
    author_email='infosulaiman@icloud.com',
    license='LGPLv3',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Developers',
        'Intended Audience :: Information Technology',
        'Intended Audience :: System Administrators',
        'Topic :: Security',
        'Topic :: Internet :: Log Analysis',
        'License :: OSI Approved :: GNU Lesser General Public License v3 (LGPLv3)',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Environment :: Console',
    ],
    keywords='security monitoring siem logging signatures elasticsearch splunk ids sysmon',
    packages=[
        'threatcode',
        'threatcode.backends',
        'threatcode.config',
        'threatcode.parser',
        'threatcode.parser.modifiers',
        ],
    python_requires='~=3.6',
    install_requires=['PyYAML', 'pymisp', 'progressbar2'],
    extras_require={
        'test': ['coverage', 'yamllint'],
    },
    data_files=[
        ('etc/threatcode', [ str(p) for p in Path('config/').glob('*.yml') ]),
        ('etc/threatcode/generic', [ str(p) for p in Path('config/generic/').glob('*.yml') ])],
    entry_points={
        'console_scripts': [
            'threatcodec = threatcode.threatcodec:main',
            'merge_threatcode = threatcode.merge_threatcode:main',
            'threatcode2misp = threatcode.threatcode2misp:main',
            'threatcode2attack = threatcode.threatcode2attack:main',
            'threatcode_similarity = threatcode.threatcode_similarity:main',
            'threatcode_uuid = threatcode.threatcode_uuid:main',
        ],
    },
)
