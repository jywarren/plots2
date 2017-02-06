function setupWiki(node_id, raw) {

  // insert inline forms
  if (raw) {
    $('#content-raw-markdown').html(shortCodePrompt($('#content-raw-markdown')[0], { submitUrl: '/wiki/replace/' + node_id }));

    $('#content').html('');

// THIS DOESN"T WORK BECAUSE IT"S NOT HTML YET


    var sections = $('#content-raw-markdown').find('h1,h2,h3,h4,p,ul');
    sections.each(forEachSection);

  } else {
    $('#content').html(shortCodePrompt($('#content')[0], { submitUrl: '/wiki/replace/' + node_id }));
  }

  /* setup bootstrap behaviors */
  $("[rel=tooltip]").tooltip()
  $("[rel=popover]").popover({container: 'body'})
  $('table').addClass('table')
  
  $('iframe').css('border','none')
  
  /* add "link" icon to headers */
  $("#content h1, #content h2, #content h3, #content h4").append(function(i,html) {
    return " <small><a href='#" + this.innerHTML.replace(/ /g,'+') + "'><i class='icon fa fa-link'></i></a></small>";
  });

}

function forEachSection(index, section) {
  var markdown = $(section).html(),
      html     = replaceWithMarkdown(html),
      uniqueId = "section-form-" + index;

  $('#content').append(markdown);
  var el = $('#content > *:last');
console.log(section, el);

  el.append("<div class='well' id='" + uniqueId + "'><p>Markdown:</p><textarea class='form-control'>" + markdown + "</textarea></div>");

  // build a form to attach:

  function onComplete(response) {
    var message = $('#' + uniqueId + ' .prompt-message');
    if (response === 'true' || response === true) {
      message.html('<i class="fa fa-check" style="color:green;"></i>');
      var input = $('#' + uniqueId + ' .form-control').val();
      var form = $('#' + uniqueId).before('<p>' + input + '</p>');
      $('#' + uniqueId + ' .form-control').val('');
    } else {
      message.html('There was an error. Do you need to <a href="/login">log in</a>?');
    }
  }

  function onFail(response) {
    var message = $('#' + uniqueId + ' .prompt-message');
    message.html('There was an error. Do you need to <a href="/login">log in</a>?');
  }

  function submitSectionForm(e) {
    $.post(options.submitUrl, {
      before: markdown,
      after: after
    })
     .done(onComplete)
     .fail(onFail);
  }
}

function replaceWithMarkdown(element) {
  var markdown = megamark(
    element,
    { 
      sanitizer: {  
        allowedTags: [
          "a", "article", "b", "blockquote", "br", "caption", "code", "del", "details", "div", "em",
          "h1", "h2", "h3", "h4", "h5", "h6", "hr", "i", "img", "ins", "kbd", "li", "main", "ol",
          "p", "pre", "section", "span", "strike", "strong", "sub", "summary", "sup", "table",
          "tbody", "td", "th", "thead", "tr", "u", "ul", 
          "form", "input", "textarea", "div", "script", "iframe", "button"
        ],
        allowedAttributes: {
          a: ['class', 'id', 'href'],
          button: ['class', 'id'],
          div: ['class', 'id'],
          form: ['class', 'id'],
          input: ['class', 'id', 'name', 'placeholder'],
          textarea: ['class', 'id', 'name', 'placeholder'],
          iframe: ['class', 'id', 'src']
        },
        allowedClasses: {
          button: ['class'],
          input: ['class'],
          a: ['class'] ,
          div: ['class']
        }
        //"allowedClasses": "class"
      }
    }
  );
  return markdown;
}
