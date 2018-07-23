import os, re, glob

# compile regex patterns beforehand
START = re.compile(r'^\t*--\[\[ ?((\w+)[:.](.+))$')
STOP = re.compile(r'^\t*--\]\]$')

# create a dictionary to store our pages
pages = {}

print('Parsing documentation in \'{}\''.format(os.getcwd()))
for file in glob.glob('**/*.lua', recursive=True):
	# iterates recursively for every Lua file, then open file for reading
	with open(file) as f:
		isReading = False
		textBlock = ''
		isHeader = False
		pageName = None
		numBlocks = 0

		# traverse file line-by-line for content
		for line in f:
			if not isReading:
				# we're not currently reading a text block, search for the start of one
				header = START.match(line)
				if header:
					# found a text block
					# the expected format is:
					# "--[[ PageName:foo..."
					if header.group(3).lower() == 'header':
						# our "foo" was "header", which signifies this should be text on top of
						# the page, but there's already a dedicated heading for the page
						isHeader = True
					else:
						# everything else gets h3
						textBlock = '### {}\n\n'.format(header.group(1))

					# store the page name and toggle reading mode
					pageName = header.group(2)
					isReading = True
			else:
				# we're reading, check if the line signifies the end of a block
				if STOP.match(line):
					# line signified the end of a block, we'll need to store it
					# the expected format is:
					# "--]]"
					if not pageName in pages:
						# page does not have a list to store blocks in - create it
						pages[pageName] = []

					if isHeader:
						# the block was a header, we need to put it at the top of the list of blocks
						pages[pageName].insert(0, textBlock)
					else:
						# normal block, just append it
						pages[pageName].append(textBlock)

					# reset back to normal
					isReading = False
					isHeader = False
					textBlock = ''
					pageName = None
					numBlocks += 1
					continue
				else:
					# we're currently in the middle of a block, just store the line
					# we also need to strip leading tabs, forcing indented text blocks to use
					# spaces within as whitespace if needed
					textBlock += line.lstrip('\t')

		if numBlocks > 0:
			# at the end of a file, if we found some blocks, log it
			print('- Found {} blocks in \'{}\''.format(numBlocks, file))


# done parsing docs, let's write it out
print('\nWriting to files')

for name, blocks in pages.items():
	# iterates over 'pages' dict
	# figure out the path we want to save to, and log it
	path = '.wiki/{}.md'.format(name)
	print('- {}'.format(path))

	with open(path, 'w') as f:
		# open the output file for writing, join the blocks for the page, then write
		f.write('\n***\n\n'.join(blocks))

print('\nDone!')
