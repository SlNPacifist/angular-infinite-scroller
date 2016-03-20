About this package
------------------

Infinite scrolling is a very tricky area. Different packages solve problems of infinite scroll in
different ways, this package uses its own way.

###Description

**Scroller** is an [angular.js 1](https://angularjs.org/) directive. It is used much like ngRepeat
directive: every element of collection instantiates a template. Unlike ngRepeat, data source is a
function that can load data in small parts when needed.

###Usage

Include minified scroller file in your template:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.min.js" type="text/javascript"></script>
```

or full version:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.min.js" type="text/javascript"></script>
```

Now you can use directives:

```html
<ANY scroller-viewport scroller-source="getData" scroller-settings="scrollerViewportSettings">
    <ANY scroller-item>{{scrData.data}}</ANY>
</ANY>
```

`scroller-viewport` is a directive that manages data: it measures scroll position inside of bound
element and makes decision to render or delete new items at the beginning or at the end of
rendered range.

`scroller-item` is a directive that is repeated for every rendered item. Note that contents of
viewport may be arbitrary and scroller-item could be used several times:

```html
<div class="editor-body" scroller-viewport scroller-source="getData">
    <div class="numbers"><p scroller-item>{{scrData.index}}</p></div>
    <div class="text"><p scroller-item>{{scrData.data}}</p></div>
</div>
```

In this example both index and data will be rendered for every item. That is useful when you want to
render parts of your items in different parts of viewport.

`scroller-source` attribute should refer a `function(index, count, callback)`:

* `index` - integer, could be any integer (even less then zero)
* `count` - integer, 1 or greater
* `callback` - `function(err, res)`:
    
    * `err` if err is set no action is performed
    * `res` should be an array. Items of this array will become scrData.data in scroller-item. `res`
should contain `count` items starting with `index`.


###Dependencies

Scroller only requires angular.js. No need to install jQuery or other libraries.
