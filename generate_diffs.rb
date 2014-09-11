require "diffy"
require "zlib"

ATTIC = "#{ENV["HOME"]}/Sites/wiki/data/attic"
PAGES = "#{ENV["HOME"]}/Sites/wiki/data/pages"
DOTSFILE = "#{ENV["HOME"]}/Sites/wiki/data/pages/special/dots.txt"

def file_from(path)
  path.to_s.split("/")[-1]
end

def pagename_from(file)
  file.split(".")[0]
end

def timestamp_from(file)
  file.split(".")[1].to_i
end

def page_exists?(file)
  File.exist?("#{PAGES}/#{pagename_from file}.txt")
end

def maybe_path_from(pagename, timestamp)
  f = "#{ATTIC}/#{pagename}.#{timestamp}.txt.gz" 
  File.exist?(f) ? f : nil
end

def prior_to(pagename, timestamp)
  Dir.glob("#{ATTIC}/#{pagename}.*.txt.gz")
    .select { |path| timestamp_from(file_from(path)) < timestamp }
    .last
end

def text_of(maybe_path)
  maybe_path.nil? ? "" : Zlib::GzipReader.open(maybe_path) { |gz| gz.read }
end

def diffcount_of(pagename, timestamp)
  Diffy::Diff
    .new(text_of(prior_to(pagename, timestamp)),
         text_of(maybe_path_from(pagename, timestamp)))
    .count
end

def day_of(timestamp)
  Time.at(timestamp).wday
end

if __FILE__ == $0
  a_week = 60*60*24*6
  first_day = Time.at(Time.now.to_i - a_week).wday
  weekdays = %w[M T W T F S S]
  
  puts "running"

  label_row = "<tfoot><td></td>" + (0..6).map { |i| "<th>#{weekdays[(first_day+i)%7]}</th>" }.join("") + "</tfoot>"
  data_rows = Dir.glob("#{ATTIC}/*.gz")
    .select { |path| timestamp_from(file_from path) > Time.now.to_i - a_week }
    .select { |path| page_exists?(file_from path) }
    .sort { |path_a, path_b| timestamp_from(file_from path_b) <=> timestamp_from(file_from path_a) }
    .group_by { |path| pagename_from(file_from path) }
    .inject({}) { |pages, (pagename, paths)|
                  pages[pagename] = paths
                    .map { |path| timestamp_from(file_from path) }
                    .map { |timestamp| [timestamp, diffcount_of(pagename, timestamp)] }
                    .group_by { |timestamp,_| day_of timestamp }
                    .inject({}) { |days, (day, data)| days[day] = data.map { |_,diffcount| diffcount }.inject(0, :+); days }
                  pages }
    .map { |pagename, days|
           "<tr><th scope=\"row\">#{pagename}</th>" \
           + (0..6).map { |i| "<td>#{days[(first_day+i)%7] || 0}</td>" }.join("") \
           + "</tr>" }
    .first(20)
    .join("\n")

  File.open(DOTSFILE, "w") { |file| file.write "<html><div id=\"changes-chart\"></div><table id=\"changes\">\n#{label_row}\n<tbody>\n#{data_rows}\n</tbody>\n</table></html>" }
end
