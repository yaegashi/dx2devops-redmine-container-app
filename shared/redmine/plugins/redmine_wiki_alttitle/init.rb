require 'redmine'

Redmine::Plugin.register :redmine_wiki_alttitle do

  name 'Wiki alternative title plugin'
  author 'YAEGASHI Takeshi'
  description 'Wiki macro to add an alternative title to each page.'
  version '0.5'

end

Redmine::WikiFormatting::Macros.register do

  desc "Alternative Title tag"
  macro :AltTitle do |obj, args|
    # XXX
    args.join(",")
  end

  desc "Alternative Hidden Title tag"
  macro :AltHiddenTitle do |obj, args|
    ""
  end

  desc "Alternative Summary Tag"
  macro :AltSummary do |obj, args|
    # XXX
    args.join(",")
  end

  desc "Alternative Hidden Summary Tag"
  macro :AltHiddenSummary do |obj, args|
    ""
  end

  desc "Render a wiki link with alternative title"
  macro :AltLink do |obj, args|

    def self.find_tags(text)
      t = /\{\{alt(hidden)?title\((.*?)\)\}\}/mi.match(text) ? $2 : nil
      s = /\{\{alt(hidden)?summary\((.*?)\)\}\}/mi.match(text) ? $2 : nil
      [t, s]
    end

    t = s = nil
    title = args.shift
    if title
      page = @project.wiki.find_page(title)
    else
      raise "Invalid argument"
    end

    if page && !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
      raise "Cannot access: #{h(title)}"
    end

    if page.nil?
      link_to(h(title),
              {:controller => 'wiki', :action => 'show',
                :project_id => @project, :id => title},
                :class => 'wiki-page new')
    else
      t, s = find_tags(page.text)
      link_to(h(t ? t : title),
              {:controller => 'wiki', :action => 'show',
                :project_id => page.project, :id => page.title},
                :class => 'wiki-page')
    end

  end

  desc "Render wiki index with alternative title"
  macro :AltIndex do |obj, args|

    def self.find_tags(text)
      t = /\{\{alt(hidden)?title\((.*?)\)\}\}/mi.match(text) ? $2 : nil
      s = /\{\{alt(hidden)?summary\((.*?)\)\}\}/mi.match(text) ? $2 : nil
      [t, s]
    end

    def self.recursive_parent(page)
      html = "<li>"
      t, s = find_tags(page.text)
      html += link_to(h(t ? t : page.pretty_title),
                      {:controller => 'wiki', :action => 'show',
                        :project_id => page.project, :id => page.title})
      html += " <span style=\"opacity:0.4;font-size:90%;\">(#{h(s)})</span>" if s
      html += recursive_children(page)
      html += "</li>"
      html
    end

    def self.recursive_children(page)
      pages = page.children
      return "" if pages.empty?
      html = "<ul>"
      pages.each do |descp|
        html += recursive_parent(descp)
      end
      html += "</ul>"
      html
    end

    args, options = extract_macro_options(args, :parent)
    page = nil
    if args.size > 0
      page = @project.wiki.find_page(args.first.to_s)
    elsif obj.is_a?(WikiContent) || obj.is_a?(WikiContent::Version)
      page = obj.page
    else
      raise "Specify page argument (ignore this error if you are previewing a new wiki entry)"
    end
    raise "Page not found" if page.nil? ||
      !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)

    if options[:parent]
      "<ul>"+recursive_parent(page)+"</ul>"
    else
      recursive_children(page)
    end.html_safe

  end

end
