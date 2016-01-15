require "mechanize"
require "csv"
require "icalendar"

MATR = Integer(ARGV[0])
FNAM = String(ARGV[1])
CSVU = "http://www2.htw-dresden.de/~rawa/cgi-bin/auf/raiplan_kal.php"

unless MATR.to_s =~ /^\d{5}$/ and FNAM =~ /^.+\.(ics|ical)$/
	puts "Usage:"
	puts "$ htwtoical <Matrikelnummer> <Dateiname>"
	exit 1
end

# fetch schedule csv from server
agent = Mechanize.new
page  = agent.get(CSVU)
form  = page.forms[1]
form.matr = MATR
form.checkbox_with(name: "w1").check # include prof names in csv
page = agent.submit(form, form.buttons.first)
# stupid page uses another form, instantly redirecting when in browser
form = page.forms.first
page = agent.submit(form)
csv = page.body.force_encoding("ISO-8859-1").encode("utf-8").gsub(/\r\n?/, "\n") # stupid non-unicode and windows nonsense..

termine = CSV.parse(csv)

# remove all that empty or irrelevant columns
termine.each do |t|
	t.delete_at(21) # Zeitspanne anzeigen als
	t.delete_at(20) # Vertraulichkeit
	t.delete_at(19) # Reisekilometer
	t.delete_at(18) # Privat
	t.delete_at(17) # Priorität
	t.delete_at(15) # Kategorien
	t.delete_at(14) # Beschreibung
	t.delete_at(13) # Abrechnungsinformation	
	t.delete_at(12) # Besprechungsressourcen
	t.delete_at(11) # Optionale Teilnehmer
	t.delete_at(10) # Erforderliche Teilnehmer
	t.delete_at(9)  # Besprechungsplanung
	t.delete_at(8)  # Erinnerung um
	t.delete_at(7)  #            am
	t.delete_at(6)  #            ob
	t.delete_at(5)  # ganztägiges Ereignis
end

# fetch class titles into extra array for choosing what to delete
names = []
termine.each do |t|
	names << t.first
end
names = names.uniq[1..-1]

puts "Welche sollen nicht übernommen werden (Zahlen,durch Komma getrennt)?"
names.count.times do |i|
	puts "[#{i}] #{names[i]}"
end
print "#> "
rem = STDIN.gets.chomp
unless rem =~ /^(\d+,)*\d+$/
	puts "I said format like '1,4,5'!"
	exit 1
end

rem = rem.split(',').collect! { |n| n.to_i }
rem.each do |i|
	termine.reject! do |t|
		t.first == names[i]
	end
end
termine = termine[1..-1] # remove header

# convert to iCalendar format
cal = Icalendar::Calendar.new
termine.each do |t|
	stdate = t[1].split('.').map { |x| x.to_i }
	endate = t[3].split('.').map { |x| x.to_i }
	sttime = t[2].split(':').map { |x| x.to_i }
	entime = t[4].split(':').map { |x| x.to_i }

	loc    = t[5]
	title  = t[0]
	cal.event do |e|
		e.summary = title
		e.location = loc
		e.dtstart  = DateTime.civil(stdate[2], stdate[1], stdate[0],
		                            sttime[0], sttime[1], sttime[2])
		e.dtend    = DateTime.civil(endate[2], endate[1], endate[0],
		                            entime[0], entime[1], entime[2])
	end
end

File.open(FNAM, 'w') do |f|
	f.puts cal.to_ical
end
