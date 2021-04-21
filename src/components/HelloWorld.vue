<template>
  <div>
    <el-input
      type="textarea"
      :rows="2"
      placeholder="请输入内容"
      @change="sqlchange"
      :autosize="{ minRows: 8, maxRows: 16 }"
      v-model="sqlinput"
    >
    </el-input>
    <div style="margin: 20px 0"></div>
    <vue-json-editor
      v-model="schema"
      :showBtns="true"
      :mode="'text'"
      lang="zh"
      @json-change="onJsonChange"
      @json-save="onJsonSave"
      @has-error="onError"
    />
    <br />
    <div style="margin: 20px 0"></div>
    <el-row>
      <el-col :span="24">
        <s-json-schema-editor
          :key="schemaKey"
          :schema.sync="schema"
          :show-default-value="true"
          :is-mock="true"
          @schema-change="onSchemaChange"
        >
        </s-json-schema-editor>
      </el-col>
    </el-row>
    <div style="margin: 20px 0"></div>
    <el-row>
      <el-input
        type="textarea"
        :rows="16"
        placeholder="请输入内容"
        @change="sqlchange"
        :autosize="{ minRows: 8, maxRows: 16 }"
        v-model="output"
      >
      </el-input>
    </el-row>
  </div>
</template>

<script>
import vueJsonEditor from "vue-json-editor";
import { Parser } from "sql-ddl-to-json-schema";
export default {
  name: "HelloWorld",
  components: { vueJsonEditor },
  data() {
    return {
      schemaKey: "19878878",
      schema: {
        type: "object",
        title: "title",
        properties: {
          field_1: {
            type: "string",
          },
        },
      },
      jsonformat: {},
      sqlinput: `CREATE TABLE \`gb_goods\` (
          \`goods_id\` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '商品id',
          PRIMARY KEY (\`goods_id\`) USING BTREE
          ) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COMMENT = '商品表' ROW_FORMAT = Dynamic;`,
      output: "",
    };
  },
  created() {},
  mounted() {
    this.sqlchange(this.sqlinput)
    this.schemaKey = Date.now();
  },
  methods: {
    onJsonChange(value) {
      this.onJsonSave(value);
    },
    onJsonSave(value) {
      this.schemaKey = Date.now();
      this.jsonformat = value;
      this.schema = Object.assign({}, this.jsonformat);
    },
    sqlchange(v) {
      const parser = new Parser("mysql");
      const options = { useRef: false };
      parser.feed(v);
      const doc = parser.toJsonSchemaArray(options);
      const ob = JSON.parse(JSON.stringify(doc[0]));
      this.schema = Object.assign({}, ob);
      this.schemaKey = Date.now();
    },
    onError(value) {
      console.log("json错误了value:", value);
    },
    checkJson() {
      if (this.hasJsonFlag == false) {
        alert("json验证失败");
        return false;
      } else {
        alert("json验证成功");
        return true;
      }
    },
    onSchemaChange(v) {
      this.schema = JSON.stringify(v, null, 2);
      //
      this.handleObjectOutput(v);
    },
    handleObjectOutput(v) {
      function toCamelCase(str) {
        var regExp = /[-_]\w/gi;
        return titleCase(
          str.replace(regExp, function (match) {
            return match.charAt(1).toUpperCase();
          })
        );
      }

      function titleCase(str) {
        const newStr = str.slice(0, 1).toUpperCase() + str.slice(1);
        return newStr;
      }

      function lowerCase(str) {
        const newStr = str.slice(0, 1).toLowerCase() + str.slice(1);
        return newStr;
      }

      function typeMap(str) {
        const kv = {
          integer: "int64",
          string: "string",
          number: "float64",
        };
        return kv[str];
      }

      const requires = v.required;
      const properties = v.properties;
      const tableName = toCamelCase(v.title);
      const tableNameLower = lowerCase(tableName);
      var paramsheader = `
      type ${tableName}Params struct {\n`;
      var center = ``;
      var paramstail = `}`;
      var optCommon = ``;

      var filterHeader = `
      func (opt *${tableNameLower}Q) Filter(para *${tableName}ReqParams) *${tableNameLower}Q {
        	if para != nil {
		        opt.Select(para.Fields...)
		        opt.Pagination(para)
		        if para.Query != nil {
      `
      var filtercenter = ``;
      var filtertail = `}}
      return opt}`;

      Object.keys(properties).forEach(function (key) {
        const o = properties[key];
        const skey = toCamelCase(key);
        const type = typeMap(o.type);
        if (key.indexOf("_time") > -1) {
          center += `${skey}Interval []interface{} \`json:"${key}|interval,omitempty"\`\n`;
          filtercenter += `	
          if len(para.Query.${skey}Interval) > 0 {
				    opt.${skey}Interval(para.Query.${skey}Interval)
			    }
          `  
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}(interval []interface{}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                	db = db.Clauses(
                      TimeStampDate{
                        Column: "create_time",
                        Values: interval,
                      })
		            return db
	            }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
        }

        if (key.indexOf("_id") > -1  || key == "id") {
          center += `${skey}In []${type} \`json:"${key}|in,omitempty"\`\n`;
          filtercenter += `	
          if len(para.Query.${skey}In) > 0 {
				    opt.${skey}In(para.Query.${skey}In...)
			    }
          `  
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}In(${skey}s ...${type}) *${tableNameLower}Q {
              	fn := func(db *gorm.DB) *gorm.DB {
		            db = db.Where(obj.Mgr.PreTableName("${key} in (?)"), ${skey}s)
		            return db
	             }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
        }

        if (requires.indexOf(key) > -1) {
          center += `${skey} ${type} \`json:"${key},omitempty"\`\n`;
          filtercenter += `	
          if para.Query.${skey} != "" {
				    opt.${skey}(para.Query.${skey})
			    }
          `  
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}(${skey} ${type}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                db = db.Where(obj.Mgr.PreTableName("${key} = ?"), ${skey})
                return db
              }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
          if (type == "string") {
            center += `${skey}Like ${type} \`json:"${key}|like,omitempty"\`\n`;
            filtercenter += `	
            if para.Query.${skey}Like != "" {
              opt.${skey}Like(para.Query.${skey}Like)
            }
            `  
            optCommon += `
            func (obj *${tableNameLower}Q) ${skey}Like(${skey} ${type}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                db = db.Where(obj.Mgr.PreTableName("${key} like ?"), "%"+${skey}+"%")
                return db
              }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
          }
        }
      });
      this.output = paramsheader + center + paramstail + 
      "\n" + optCommon + filterHeader + filtercenter + filtertail;
    },
  },
};
</script>

<style>
</style>
