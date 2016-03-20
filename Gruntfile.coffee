module.exports = (grunt) ->
    grunt.loadNpmTasks 'grunt-coffeelint'
    grunt.loadNpmTasks 'grunt-contrib-coffee'
    grunt.loadNpmTasks 'grunt-contrib-uglify'
    grunt.loadNpmTasks('grunt-docco')
    grunt.loadNpmTasks('grunt-github-pages')
    grunt.registerTask('build', ['coffeelint', 'coffee', 'uglify'])
    grunt.registerTask('compile-docs', ['coffeelint', 'docco'])
    grunt.registerTask('upload-docs', ['compile-docs', 'githubPages'])
    grunt.initConfig
        pkg: grunt.file.readJSON 'package.json'
        coffeelint:
            src: 'src/**/*.coffee'
            options:
                max_line_length:
                    level: 'ignore'
                indentation:
                    value: 4
                    level: 'error'
                line_endings:
                    value: 'unix'
                    level: 'error'
                no_stand_alone_at:
                    level: 'error'
                newlines_after_classes:
                    value: 2
                    level: 'error'
        coffee:
            compile:
                files: [
                    expand: true
                    cwd: 'src/'
                    src: '**/*.coffee'
                    dest: 'dist/'
                    ext: '.js'
                ]
        uglify:
            dist:
                src: ['dist/scroller.js']
                dest: 'dist/scroller.min.js'
        docco:
            publish:
                src: ['src/**/*.coffee'],
                options:
                  output: '../scroller-pages/docs/'
        githubPages:
            publish:
                options:
                    commitMessage: 'Auto documentation update'
                src: '../scroller-pages'
