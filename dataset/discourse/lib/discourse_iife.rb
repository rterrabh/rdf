class DiscourseIIFE < Sprockets::Processor

  def evaluate(context, locals)

    path = context.pathname.to_s

    return data unless (path =~ /\/javascripts\/discourse/ || path =~ /\/javascripts\/admin/ || path =~ /\/test\/javascripts/)

    return data if (path =~ /test\_helper\.js/)
    return data if (path =~ /javascripts\/helpers\//)

    return data if (path =~ /\.es6/)

    return data if (path =~ /\/translations/)

    return data if path =~ /\.handlebars/
    return data if path =~ /\.shbrs/
    return data if path =~ /\.hbrs/
    return data if path =~ /\.hbs/

    "(function () {\n\nvar $ = window.jQuery;\n// IIFE Wrapped Content Begins:\n\n#{data}\n\n// IIFE Wrapped Content Ends\n\n })(this);"
  end

end
