import os
import shutil
import sys
#file_path=sys.argv[1]
file_path='./05contrasts'
media_connect="/"
DE_results=[]
pdf=[]

co_DE_results=[]
co_pdf=[]
total_file=os.listdir(file_path)

def f1():
    for i in total_file:
        if i.endswith("DE_results"):
            DE_results.append(i)

        if i.endswith("pdf"):
            pdf.append(i)

def f2():
    for i in DE_results:
        co_DE_results.append(i[20:-18])

    for i in pdf:
        co_pdf.append(i[20:-35])

def f3():
    guiyi_DE_results=sorted(co_DE_results)
    guiyi_pdf=sorted(co_pdf)

    if (guiyi_DE_results==guiyi_pdf):
        co_total=guiyi_DE_results+guiyi_pdf

    de_duplication_co_total=[]
    for i in co_total:
        if i not in de_duplication_co_total:
            de_duplication_co_total.append(i)

    result_pathfile=[]
    for i in de_duplication_co_total:
        result_pathfile.append(file_path+media_connect+i)
    return result_pathfile

def f4():
    total_profile=f3()
    for i in total_profile:
        if not os.path.exists(i):
            os.makedirs(i)
        else:
            pass

f1()
f2()
f3()
f4()
total_profile=f3()

DE_results_addpath=[]
pdf_addpath=[]

def f5():

    for i in DE_results:
        DE_results_addpath.append(file_path+media_connect+i)

    for i in pdf:
        pdf_addpath.append(file_path+media_connect+i)

    total_profile=f3()

    if (len(total_profile) == len(DE_results_addpath) == len(pdf_addpath)):

        for i in range(len(total_profile)):

            for j in range(len(DE_results_addpath)):

                end_total_profile=total_profile[i].split(media_connect)[-1]
            
                end_DE_results_addpath=DE_results_addpath[j].split(media_connect)[-1]
            
                end_pdf_addpath=pdf_addpath[j].split(media_connect)[-1]

                if (end_DE_results_addpath[20:-18] == end_total_profile):
                    shutil.move(DE_results_addpath[j],total_profile[i])

                if (end_pdf_addpath[20:-35] == end_total_profile):
                    shutil.move(pdf_addpath[j],total_profile[i])

f5()

R_path=[]
for i in DE_results:
    media=i
    R_path.append(file_path+media_connect+i[20:-18]+media_connect+i)

r_script="two_group_DEGs_result.txt"   
r_path=open(file_path+media_connect+r_script,"w")
for i in R_path:
    r_path.write(i+"\n")
r_path.close()
    
