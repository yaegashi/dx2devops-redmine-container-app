require 'redmine'

Redmine::Plugin.register :redmine_wiki_excerpt do

  name 'Wiki excerpt macro plugin'
  author 'YAEGASHI Takeshi'
  description 'Wiki macro to render excerpts from wiki pages/board messages'
  version '0.6'

end

Redmine::WikiFormatting::Macros.register do

  desc "Excerpt tag"
  macro :T do |obj, args|
    ""
  end

  desc "Render excerpt-tagged text from wiki pages/board messages"
  macro :excerpt do |obj, args|

    def self.text_cutter(text, tag)
      return text if tag.blank?
      result = ""
      including = false
      text.each_line do |i|
        case i.chomp
        when /^\s*\{\{T(\((.*)\))?\}\}\s*$/
          including = $2 == tag
        else
          result << i if including
        end
      end
      result
    end

    tag = args.shift
    args.map!(&:strip)
    messages = []
    options = {}
    cond = Project.visible_condition(User.current)

    args.each do |i|
      n = nil
      case i
      when /^wiki:(.*)$/
        m = @project.wiki.find_page($1)
        n = m ? [[m, "[[#{m.title}]]", m.text]] : [[i]]
      when /^message:(\d+)$/
        m = Message.joins(:board=>:project).where(cond).where(:id=>$1).first
        n = m ? [[m, "message##{m.id}", m.content]] : [[i]]
      when /^topic[:#](\d+)$/
        m = Message.joins(:board=>:project).where(cond).where(:id=>$1).first
        if m
          n = [[m.root, "message##{m.root.id}", m.root.content]]
          m.root.children.each do |j|
            n << [j, "message##{j.id}", j.content]
          end
        else
          n = [[i]]
        end
      when /^([^=]+)=(.*)$/
        options[$1] = $2
      else
        n = [[i]]
      end
      messages += n if n
    end

    html = ""
    heading = options.fetch('h', Setting.text_formatting == 'textile' ? 'h5.' : '#####')

    messages.each do |i, j, k|
      if j.nil?
        html += textilizable("*Not found: #{i}*")
      else
        body = text_cutter(k, tag)
        if !body.blank?
          h = "#{tag}/#{j}"
          @excerpted_pages ||= []
          raise 'Circular excerpt detected' if @excerpted_pages.include?(h)
          @excerpted_pages << h
          head = heading.blank? ? "" : "#{heading} #{j}\n\n"
          html += textilizable(head+body, :headings => false, :object => i)
          @excerpted_pages.pop
        end
      end
    end

    html.html_safe

  end

end
