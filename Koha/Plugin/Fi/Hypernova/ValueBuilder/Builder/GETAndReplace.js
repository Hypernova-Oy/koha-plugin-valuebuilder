let subroutines = {
  "f008_infer": (frameworkcode, inputElem) => {
    let f008 = inputElem.value+"";
    let m = f008.match(/^(?<dateonfile>......)(?<p1>.........)(?<placeofpub>...)(?<p2>.................)(?<lang>...)(?<p3>..)$/);
    if (! m) {
      console.log(`Plugin::Fi::Hypernova::ValueBuilder:> f008_infer:> Given field 008='${f008}' couldn't be parsed to controlfield 008 character positions.`);
      alert(`Plugin::Fi::Hypernova::ValueBuilder:> f008_infer:> Given field 008='${f008}' couldn't be parsed to controlfield 008 character positions.`);
      return null;
    }

    if (m.groups.dateonfile.match(/^[0 |#]{6}$/)) {
      let d = new Date();
      m.groups.dateonfile = d.getFullYear().toString().slice(-2)+(d.getMonth()+1).toString().padStart(2,'0')+(d.getDate()+1).toString().padStart(2, '0');
    }
    if (m.groups.placeofpub.match(/^[ |#]{3}$/)) {
      let place_of_publication = mfw_vb_get_subfield_input_element(frameworkcode, '044', 'a')?.value;
      if (place_of_publication) {
        while (place_of_publication.length < 3) {
          place_of_publication += '#';
        }
        m.groups.placeofpub = place_of_publication;
      }
    }
    if (m.groups.lang.match(/^[ |#]{3}$/)) {
      let lang = mfw_vb_get_subfield_input_element(frameworkcode, '041', 'a')?.value;
      if (lang) {
        while (lang.length < 3) {
          lang += '#';
        }
        m.groups.lang = lang;
      }
    }

    return m.groups.dateonfile+m.groups.p1+m.groups.placeofpub+m.groups.p2+m.groups.lang+m.groups.p3;
  },
};

function mfw_vb_valuebuilder(pattern, frameworkcode, fieldcode, subfieldcode, trigger) {
  let input = mfw_vb_get_subfield_input_element(frameworkcode, fieldcode, subfieldcode);

  if (subroutines[pattern]) {
    input.value = subroutines[pattern](frameworkcode, input);
    input.dispatchEvent(new Event('change'));
    return;
  }

  var itemtype = mfw_vb_get_itemtype();
  var branchcode = mfw_vb_get_branchcode();
  var biblionumber = mfw_vb_get_biblionumber();
  var currentvalue = input.value;

  var url = '/api/v1/contrib/hypernova/catalogue/valuebuilder'
  + '?currentvalue=' + currentvalue
  + '&frameworkcode=' + frameworkcode
  + '&fieldcode=' + fieldcode
  + '&subfieldcode=' + subfieldcode
  + '&itemtype=' + itemtype
  + '&branchcode=' + branchcode
  + '&biblionumber=' + biblionumber;

  fetch(url)
  .then(response => response.json())
  .then(data => {
    if (data.value) {
      if (input.tagName === 'SELECT') {
        let option = input.querySelector('option[value="'+data.value+'"]')
        if (option) {
          option.selected = true;
        }
        else {
          console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' value='${data.value}' not a valid option in the dropdown list`);
          alert(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' value='${data.value}' not a valid option in the dropdown list`);
        }
        input.value = data.value;
        input.dispatchEvent(new Event('change'));
      }
      else if (input.tagName === 'INPUT') {
        input.value = data.value;
        input.dispatchEvent(new Event('change'));
      }
    }
    else {
      throw Error(data.error);
    }
  })
  .catch(error => {
    console.log(error);
    alert('Error: '+error);
  })
  .finally(() => {
    if (trigger === "onsave") {
      mfw_vb_maybe_do_form_submit(trigger);
    }
  });
}

let formSubmissionValueBuildersWaitingToComplete = 0; // Keep track of onsave-triggered valuebuilders that are waiting for the fetch to complete
let formSubmissionTriggeringEvent; // We need to redispatch the same event from the same element, because there are multiple submit-buttons having a bit different behaviour.
function mfw_vb_bind_valuebuilder(pattern, frameworkcode, fieldcode, subfieldcode, trigger) {
  let subfield_line = mfw_vb_get_subfield_line_element(fieldcode, subfieldcode);
  if (!subfield_line) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but .subfield_line-element not found`);
    return;
  }

  let input = mfw_vb_get_subfield_input_element(frameworkcode, fieldcode, subfieldcode);

  pattern = pattern.replaceAll(/[<>]/g, '');

  if (trigger === "disabled") {
    return;
  }
  else if (trigger === "prefill") {
    let addingNewItem = mfw_vb_is_adding_new_item();
    if (addingNewItem && input && ! input.value) {
      mfw_vb_valuebuilder(pattern, frameworkcode, fieldcode, subfieldcode, trigger);
    }
  }
  else if (trigger === "onsave") {
    let formSubmitButtons = mfw_vb_get_form_submit_button_elements();
    for (let formButton of formSubmitButtons) {
      formButton.addEventListener('click', function(event) {
        formSubmissionTriggeringEvent = event;
        if (formSubmissionValueBuildersWaitingToComplete > 0) {
          event.preventDefault();
          if (input.value) {
            // Prevent fetching the ValueBuilder value if the input is already filled
            mfw_vb_maybe_do_form_submit(trigger);
            return;
          }
          mfw_vb_valuebuilder(pattern, frameworkcode, fieldcode, subfieldcode, trigger);
        }
        return true;
      });
    }
    formSubmissionValueBuildersWaitingToComplete++;
  }
  else if (trigger === "triggered") {
    // Do nothing
  }
  mfw_vb_create_trigger_button(pattern, frameworkcode, fieldcode, subfieldcode);
}

function mfw_vb_get_subfield_line_element(fieldcode, subfieldcode) {
  if (mfw_vb_kohaPage === "additem.pl") {
    return document.getElementById('subfield'+fieldcode+subfieldcode);
  }
  else if (mfw_vb_kohaPage === "addbiblio.pl") {
    if (subfieldcode === "@") subfieldcode = '00';
    return document.querySelector(".subfield_line[id^='subfield"+fieldcode+subfieldcode+"']");
  }
}
function mfw_vb_get_subfield_input_element(frameworkcode, fieldcode, subfieldcode) {
  let subfield_line = mfw_vb_get_subfield_line_element(fieldcode, subfieldcode);
  if (!subfield_line) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but subfield not found`);
    return;
  }

  let input = subfield_line.querySelector(".input_marceditor");
  if (!input) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but input not found`);
    return;
  }
  return input;
}
function mfw_vb_is_adding_new_item() {
  if (mfw_vb_kohaPage === "additem.pl") {
    return document.getElementById('f').querySelector('input[name="op"][value="cud-additem"]');
  }
  else if (mfw_vb_kohaPage === "addbiblio.pl") {
    return document.getElementById('f').querySelector('input[name="op"][value="cud-addbiblio"]')
  }
}
function mfw_vb_get_form_submit_button_elements() {
  if (mfw_vb_kohaPage === "additem.pl") {
    return document.querySelectorAll('#cataloguing_additem_newitem input[type="submit"]');
  }
  else if (mfw_vb_kohaPage === "addbiblio.pl") {
    return document.querySelectorAll('#f button#saverecord');
  }
}
function mfw_vb_create_trigger_button(pattern, frameworkcode, fieldcode, subfieldcode) {
  let subfield_line = mfw_vb_get_subfield_line_element(fieldcode, subfieldcode);
  let trigger_button = document.createElement('span');
  trigger_button.innerHTML = '<i class="fa fa-lg fa-gear"></i>';
  trigger_button.classList.add('mfw_vb_trigger_button');
  subfield_line.appendChild(trigger_button);
  trigger_button.addEventListener('click', function() {
    mfw_vb_valuebuilder(pattern, frameworkcode, fieldcode, subfieldcode, "triggered");
  });
}

function mfw_vb_get_itemtype(frameworkcode) {
  if (mfw_vb_kohaPage === "additem.pl") {
    return mfw_vb_get_subfield_input_element(frameworkcode, '952','y')?.value || '';
  }
  else if (mfw_vb_kohaPage === "addbiblio.pl") {
    return mfw_vb_get_subfield_input_element(frameworkcode, '942','c')?.value || '';
  }
}
function mfw_vb_get_branchcode(frameworkcode) {
  if (mfw_vb_kohaPage === "additem.pl") {
    return mfw_vb_get_subfield_input_element(frameworkcode, '952','a')?.value || '';
  }
  else if (mfw_vb_kohaPage === "addbiblio.pl") {
    return '';
  }
}
function mfw_vb_get_biblionumber() {
  return document.getElementsByName("biblionumber")[0]?.value || 0;
}
function mfw_vb_maybe_do_form_submit(trigger) {
  if (trigger === "onsave") {
    formSubmissionValueBuildersWaitingToComplete--;
    if (formSubmissionValueBuildersWaitingToComplete <= 0) {
      formSubmissionTriggeringEvent.target.dispatchEvent(
        new MouseEvent(formSubmissionTriggeringEvent.type)
      );
    }
  }
}
