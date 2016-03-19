console.log("this is a test.");

$(document).ready(function() {
  $(".delete").submit(function() {
    return confirm("Are you sure you wish to delete?");
  });
});