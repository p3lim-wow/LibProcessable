#!/usr/bin/env python3

import os
import sys
import csv

import requests
from bs4 import BeautifulSoup

# the column values needs to be updated manually :(
BRANCHES = {
	'Retail': {
		'column': 45 - 1, # 46 in dragonflight
	},
	'Classic': {
		'column': 42 - 1,
	},
	# XXX: Classic Era (1.14) does not have a complete itemsparse.db2,
	#      so support for it is out of the question
}

# known columns that seem to be static across branches
ID_COLUMN = 0
NAME_COLUMN = 6

# 0x8000 in Flags[0] column means not disenchantable
FLAG_VALUE = '32768'

# separator used to append the output file
SEPARATOR = '-- DO NOT REMOVE THIS LINE'


def get(path):
	# shorthand for fetching wow.tools path using a bogus user agent
	try:
		res = requests.get('https://wow.tools/' + path, headers={'User-Agent': 'libprocessable'})
		return res.content.decode('utf-8')
	except e:
		print('ERROR:', e)
		sys.exit(1)


print('Scraping wow.tools for build info')
# scrape the builds page from wow.tools (I wish the site had an API for this, it sucks to scrape)
soup = BeautifulSoup(get('builds'), 'html.parser')

# parse for the builds table
tabl = soup.find(id='buildtable')

# iterate through every td tag and its contents
tds = [td.contents for td in tabl.find_all('td')]
for index, td in enumerate(tds):
	# every 9 td tags is a row
	if index % 9 == 0:
		# parse the build version from the 1st and 2nd columns
		build = f'{td[0]}.{tds[index + 1][0]}'
		# parse the branch name from the 4th column
		branch = tds[index + 2][0].contents[0]

		# store the build for our tracked branches
		if branch in BRANCHES and not 'build' in BRANCHES[branch]:
			BRANCHES[branch]['build'] = build
			print(f'Found build {build} for {branch}!')

# grab everything before the separating block
preserve, _, _ = open('LibProcessable.lua', 'r').read().partition(SEPARATOR)

# write directly to LibProcessable.lua
with open('LibProcessable.lua', 'w') as out:
	out.write(preserve + SEPARATOR + os.linesep)

	# iterate through our tracked branches
	for branch, details in BRANCHES.items():
		print('')
		print(f'Downloading itemsparse.db2 for {branch}')
		# download the itemsparse.db2 file for the branch's build in csv format
		itemsparse = get(f'dbc/api/export/?name=itemsparse&build={details["build"]}')

		# write file head + branch wrapper
		if branch == 'Retail':
			out.write('if not CLASSIC then' + os.linesep)
		else:
			out.write('if CLASSIC then' + os.linesep)

		out.write('	data.enchantingInvalidItems = {' + os.linesep)

		# iterate through the csv file
		print(f'Parsing itemsparse.db2 for {branch}')
		numItems = 0
		for row in csv.reader(itemsparse.splitlines(), delimiter=','):
			# if the Flags[0] column matches the defined "not disenchantable" value
			if row[details['column']] == FLAG_VALUE:
				# write the itemID in a lua table format with the item name as a comment
				out.write(f'		[{row[ID_COLUMN]}] = true, -- {row[NAME_COLUMN]}{os.linesep}')
				numItems = numItems + 1

		# write file tail
		out.write('	}' + os.linesep)
		out.write('end' + os.linesep)

		print(f'Found {numItems} items!')
