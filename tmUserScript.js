// ==UserScript==
// @name         Filman - get links and mediatype
// @namespace    http://tampermonkey.net/
// @version      2024-10-18
// @description  Pobieranie linkow z filmana
// @author       You
// @match        https://filman.cc/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

let vodLink;
let videoType;
let mediaType;
let allData = [];

let link = window.location.href;
let result = link.includes('filman.cc/e/');

if (result) {
    videoType = 'Serial';

    // tytul serialu
    let s = document.querySelectorAll('h2')
    let seriesTitle = s[0].innerText.replace(/ /g,'_').replace(/[:-]/g,"").replace(/\//g,"").replace(/__/g,"_");

    // tytul + oznaczenie odcina
    let t = document.querySelectorAll('h3');
    let episodeTitleTemp = t[0].innerText.replace(/ /g,"_").replace(/\[|\]/g,"");
    let parts = episodeTitleTemp.match(/(s\d{2})(e\d{2})_(.*)/);
    let episodeTitleFormatted = `_${parts[1]}_${parts[2]}@${parts[3]}`;

    // linki i typ filmu (lektor/napisy/etc)
    let l = document.getElementById('links');

    // obrobka
    for (let i = 0; i < l.getElementsByTagName('tbody')[0].childElementCount; i++){
        let tempLink = l.getElementsByTagName('tbody')[0].children[i].getElementsByTagName('td')[0].querySelector('a').getAttribute('data-iframe');
        let decodedValue = atob(tempLink);
        let jsonObject = JSON.parse(decodedValue);
        let vodLink = jsonObject.src;
        let mediaType = l.getElementsByTagName('tbody')[0].children[i].getElementsByTagName('td')[1].innerText;
        allData.push(vodLink+"@"+mediaType+"@"+videoType+"@"+seriesTitle+"@"+episodeTitleFormatted);
    }

} else {
    videoType = 'Film';

    let t = document.querySelectorAll('h1')
    let movieTitle = t[0].childNodes[1].innerText.replace(/ /g,'_').replace(/[:-]/g,"").replace(/\//g,"").replace(/__/g,"_");

    let l = document.getElementById('links');

    for (let i = 0; i < l.getElementsByTagName('tbody')[0].childElementCount; i++){
        let test = l.getElementsByTagName('tbody')[0].children[i].children;
        if ( test.length > 0) {
            let tempLink = l.getElementsByTagName('tbody')[0].children[i].getElementsByTagName('td')[0].querySelector('a').getAttribute('data-iframe');
            let decodedValue = atob(tempLink);
            let jsonObject = JSON.parse(decodedValue);
            let vodLink = jsonObject.src;
            let mediaType = l.getElementsByTagName('tbody')[0].children[i].getElementsByTagName('td')[1].innerText;
            allData.push(vodLink+"@"+mediaType+"@"+videoType+"@"+movieTitle);
        }
    }
}

console.log(allData);

let output = '';

if (allData.length > 0) {
   output = `${allData.join('\n')}`;
}

let targetDiv = document.querySelector('div.filman');

// wywalenie na strone
const newDiv = document.createElement('div');
newDiv.style.display = 'flex';
newDiv.style.flexDirection = 'column';
newDiv.style.alignItems = 'center';
newDiv.style.justifyContent = 'center';
newDiv.setAttribute("class", "alert");

const pre = document.createElement('pre');
pre.textContent = output;
pre.style.padding = '10px';
pre.style.border = '1px solid #ccc';
pre.style.marginTop = '20px';

//document.body.appendChild(pre);
newDiv.appendChild(pre);

const copyButton = document.createElement('button');
copyButton.textContent = 'Kopiuj do schowka';

newDiv.appendChild(copyButton);

if (targetDiv && targetDiv.parentNode) {
    targetDiv.parentNode.insertBefore(newDiv, targetDiv.nextSibling);
}

copyButton.addEventListener('click', function() {
    navigator.clipboard.writeText(pre.textContent)
});

})();
