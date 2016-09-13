function setupGridSorters(selector) {
  $(selector).find('th a').click(function(a) {
    sortGrid($(a.target).attr('data-type'), selector, a.target);
  });
}

function sortGrid(type, selector, headerLink) {

  var table = $(selector),
      headerLink = $(headerLink),
      desc = headerLink.hasClass('desc'),
      header = table.find('tr:first').detach(),
      rows = table.find('tr').detach();

  rows = rows.sort(function(a, b){

    var cellA = $(a).find('.' + type);
    var cellB = $(b).find('.' + type);

    if (cellA.attr('data-timestamp')) {

      if (desc) return cellA.attr('data-timestamp') < cellB.attr('data-timestamp') ? 0 : 1;
      else      return cellA.attr('data-timestamp') > cellB.attr('data-timestamp') ? 1 : 0;
      
    } else {

      if (desc) return cellA.text() < cellB.text() ? -1 : 1;
      else      return cellA.text() > cellB.text() ? 1 : 0;

    }

    return 0;

  });

  table.html(rows);
  table.prepend(header);

  headerLink.toggleClass('desc');

}
