###  About this package

Infinite scrolling is a very tricky area. Different packages solve problems of infinite scroll in
different ways, this package uses its own way.

### Description

**Scroller** is an [angular.js 1](https://angularjs.org/) directive. It is used much like ngRepeat
directive: every element of collection instantiates a template. Unlike ngRepeat, data source is a
function that can load data in small parts when needed. Also, ngRepeat watches for content changes
while Scroller assumes data in collection is never changed (items can only be added on both sides
of collection).

### Usage

Include minified scroller file in your template:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.min.js" type="text/javascript"></script>
```

or full version:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.min.js" type="text/javascript"></script>
```

List module 'scroller' in your app module dependencies:
```javascript
    var myApp = angular.module('myApp', ['ui.scroll', ...]);
```

Now you can use directives:

```html
<ANY scroller-viewport scroller-source="getData" scroller-settings="scrollerViewportSettings">
    <ANY scroller-item>{{scrIndex}} {{scrData}}</ANY>
</ANY>
```

`scroller-viewport` is a directive that manages data: it measures scroll position inside of bound
element and makes decision to render or delete new items at the beginning or at the end of
rendered range.

`scroller-item` is a directive that is repeated for every rendered item. Note that contents of
viewport may be arbitrary and scroller-item could be used several times:

```html
<div scroller-viewport="getData">
    <div class="numbers"><p scroller-item>{{scrIndex}}</p></div>
    <div class="text"><p scroller-item>{{scrData}}</p></div>
</div>
```

In this example both index and data will be rendered for every item. That is useful when you want to
render parts of your items in different parts of viewport.

`scroller-viewport` attribute should refer a `function(index, count, callback)`:

* `index` - integer, could be any integer (even less then zero)
* `count` - integer, 1 or greater
* `callback` - `function(res)`:
    
    * `res` should be an array. Items of this array will become scrData.data in scroller-item. `res`
should contain `count` items starting with `index`.

### Known issues

Scroller does not intercept any events, so all the scrolling should work just like it is meant to
work in the operating system. However, elements far from shown area are deleted so keys like
pgUp/pgDown do not function properly. For example:

* user clicks in the scroller area
* user presses pgUp several times
* selected DOM Node is removed
* pgUp does not work anymore

### Dependencies

Scroller only requires angular.js. No need to install jQuery or other libraries.

### Development

If you want to dive into source code, compiled documentation can be found at
[github pages](https://slnpacifist.github.io/angular-infinite-scroller/docs/scroller.html)