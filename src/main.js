import ElementUI from 'element-ui';
import 'element-ui/lib/theme-chalk/index.css';
import Vue from 'vue';
import vueJsonEditor from 'vue-json-editor';
import JsonSchemaEditor from 'vue-json-schema-editor-visual';
import App from './App.vue';

Vue.use(ElementUI, { size: 'small' });
Vue.use(JsonSchemaEditor);
Vue.use(vueJsonEditor);

Vue.config.productionTip = false

new Vue({
  el: '#app',
  render: h => h(App)
})
